# GitHub tooling research

Reviewed 9 October 2026 through the Agent Reach GitHub CLI workflow, repository metadata and upstream READMEs. This is a focused shortlist for this Flutter application, not an exhaustive inventory of every mobile UI repository.

| Repository | Purpose | Decision |
| --- | --- | --- |
| [Widgetbook](https://github.com/widgetbook/widgetbook) | Isolated Flutter components, screen states and a review gallery. MIT. | Recommended development-only tool for implementation. Review dark/light, empty, error and large-text states. |
| [Flutter Animate](https://github.com/gskinner/flutter_animate) | Reusable Flutter animation effects. BSD-3-Clause. | Optional, only if Flutter's built-in animation widgets are insufficient. Short transitions with reduced-motion support. |
| [Flutter Lucide](https://github.com/ravikovind/flutter_lucide) | Consistent cross-platform icon family. MIT. | Candidate, not required. Compare against the approved icon treatment and Flutter's existing icons before adding. |
| [Impeccable](https://github.com/pbakaus/impeccable) | Design guidance and review workflows. Apache-2.0. | Existing local guidance already loaded and used. No duplicate installation needed. |
| [Flutter](https://github.com/flutter/flutter) | Existing app framework, Material components, ThemeData and native widget testing. BSD-3-Clause. | Already the framework. Retain BLoC and existing feature architecture. |

Searches also inspected Flutter design-system starters. They are references rather than wholesale replacements because ROZZ already has working application logic and a visual-token layer.

The user subsequently selected images first, followed by implementation after image finalization. Therefore no runtime packages, tool repositories or new agent skills were installed. Native image generation and the already available imagegen-frontend-mobile skill produce the concept images. Installation of selected development tools is deferred to implementation and should use pinned pub dependencies, review compatibility and preserve license notices. No complete template application is necessary.
