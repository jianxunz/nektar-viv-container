#!/usr/bin/env python3
from pathlib import Path
import re
import sys


def replace_once(text, old, new, description):
    if old not in text:
        return text
    print(f"patch: {description}")
    return text.replace(old, new, 1)


def regex_replace_once(text, pattern, repl, description):
    new_text, count = re.subn(pattern, repl, text, count=1, flags=re.S)
    if count:
        print(f"patch: {description}")
    return new_text


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch_moving_body.py /path/to/nektar-source")

    src = Path(sys.argv[1])
    path = src / "solvers" / "IncNavierStokesSolver" / "Forcing" / "ForcingMovingBody.cpp"
    text = path.read_text()

    if "#include <cmath>" not in text:
        text = replace_once(
            text,
            "#include <IncNavierStokesSolver/Forcing/ForcingMovingBody.h>",
            "#include <cmath>\n\n#include <IncNavierStokesSolver/Forcing/ForcingMovingBody.h>",
            "include <cmath>",
        )

    text = regex_replace_once(
        text,
        r"sin\(\s*M_PI\s*/\s*\(N\)\s*\*\s*\(k\s*\+\s*1\s*/\s*2\)\s*\*\s*\(i\s*\+\s*1\)\s*\)",
        "sin(M_PI / static_cast<NekDouble>(N) *\n"
        "                            (static_cast<NekDouble>(k) + 0.5) *\n"
        "                            (static_cast<NekDouble>(i) + 1.0))",
        "Pinned-Pinned forward sine transform half-index",
    )

    text = regex_replace_once(
        text,
        r"sin\(\s*M_PI\s*/\s*\(N\)\s*\*\s*\(k\s*\+\s*1\)\s*\*\s*\(i\s*\+\s*1\s*/\s*2\)\s*\)\s*\*\s*2\s*/\s*N",
        "sin(M_PI / static_cast<NekDouble>(N) *\n"
        "                            (static_cast<NekDouble>(k) + 1.0) *\n"
        "                            (static_cast<NekDouble>(i) + 0.5)) *\n"
        "                        2.0 / static_cast<NekDouble>(N)",
        "Pinned-Pinned inverse sine transform half-index",
    )

    if "StructReducedVelocity" not in text:
        marker = '    m_session->LoadParameter("BendingStiff", bendingstiff, 0.0);\n'
        insert = r'''

    bool hasBendingStiffRatio = false;
    NekDouble bendingstiffRatio = 0.0;
    if (m_session->DefinesParameter("BendingStiffRatio"))
    {
        hasBendingStiffRatio = true;
        m_session->LoadParameter("BendingStiffRatio", bendingstiffRatio);
        bendingstiff = bendingstiffRatio * cabletension;
    }

    if (m_session->DefinesParameter("StructReducedVelocity"))
    {
        NekDouble reducedVelocity;
        NekDouble referenceVelocity;
        NekDouble referenceDiameter;
        m_session->LoadParameter("StructReducedVelocity", reducedVelocity);
        m_session->LoadParameter("StructReferenceVelocity", referenceVelocity,
                                 1.0);
        m_session->LoadParameter("StructReferenceDiameter", referenceDiameter,
                                 1.0);

        ASSERTL0(reducedVelocity > 0.0 && referenceVelocity > 0.0 &&
                     referenceDiameter > 0.0,
                 "StructReducedVelocity, StructReferenceVelocity and "
                 "StructReferenceDiameter must be positive.");

        NekDouble beta1        = M_PI / m_lhom;
        NekDouble beta1Sq      = beta1 * beta1;
        NekDouble targetOmega1 = 2.0 * M_PI * referenceVelocity /
                                 (reducedVelocity * referenceDiameter);
        NekDouble targetOmega1Sq = targetOmega1 * targetOmega1;

        if (hasBendingStiffRatio)
        {
            NekDouble denominator =
                beta1Sq + bendingstiffRatio * beta1Sq * beta1Sq;
            cabletension =
                (m_structrho * targetOmega1Sq - structstiff) / denominator;
            bendingstiff = bendingstiffRatio * cabletension;
        }
        else
        {
            cabletension =
                (m_structrho * targetOmega1Sq - structstiff -
                 bendingstiff * beta1Sq * beta1Sq) /
                beta1Sq;
        }

        ASSERTL0(cabletension > 0.0,
                 "StructReducedVelocity gives a non-positive cable tension. "
                 "Check LZ, StructRho, StructStiff, BendingStiff and the "
                 "target reduced velocity.");
    }

    if (m_session->DefinesParameter("StructDampingRatio"))
    {
        NekDouble dampingRatio;
        m_session->LoadParameter("StructDampingRatio", dampingRatio);

        NekDouble beta1 = M_PI / m_lhom;
        NekDouble omega1Sq =
            (structstiff + cabletension * beta1 * beta1 +
             bendingstiff * beta1 * beta1 * beta1 * beta1) /
            m_structrho;
        ASSERTL0(omega1Sq > 0.0,
                 "StructDampingRatio requires a positive first natural "
                 "frequency. Check StructStiff, CableTension, BendingStiff "
                 "and StructRho.");

        NekDouble omega1 = std::sqrt(omega1Sq);
        m_structdamp += 2.0 * dampingRatio * omega1 * m_structrho;
    }
'''
        if marker not in text:
            raise SystemExit("could not locate BendingStiff parameter load")
        text = text.replace(marker, marker + insert, 1)
        print("patch: StructReducedVelocity, StructDampingRatio, BendingStiffRatio")

    path.write_text(text)


if __name__ == "__main__":
    main()
