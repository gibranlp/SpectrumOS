# SpectrumOS Working Instructions

These instructions apply to the entire repository and must be read before making changes.

## Language convention

- Communicate with the user in English.
- Write project documentation, commit messages, user-facing messages, identifiers, and code in English unless a specific requirement says otherwise.
- Use code comments only for important functions or genuinely non-obvious behavior. Do not narrate straightforward code.
- Write every code comment in natural Mexican Spanish, with a balanced tone: neither highly formal nor overly casual.
- Preserve required technical directives such as shebangs, generated headers, SPDX identifiers, tool pragmas, and third-party text in their mandated format; these are not ordinary explanatory comments.

## ISO build authorization

- Never start, resume, or trigger an ISO build unless the user explicitly instructs you to build the ISO in the current conversation.
- Requests to prepare, fix, validate, publish packages, or make the repository ready for an ISO do not authorize building the ISO.

## Local deployment preference

- Deploy completed SpectrumOS changes to this PC as part of the task, then verify the installed files and affected running service or generated configuration.
- This standing preference authorizes local deployment of requested fixes. Keep the ISO build restriction above in force.

## Shell widget stacking

- Widgets must emerge from behind the bar and frame throughout opening, closing, and bounce animations; they must not cover the bar or intercept its controls.
- Keep ordinary widget panels on `WlrLayer.Top` beneath the bars and `ShellFrame` on `WlrLayer.Overlay`. Reuse the shared shell motion and attachment geometry for both bar orientations.
