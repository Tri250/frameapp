# Local policy pages

[简体中文](README.md) | [English](README.en.md)

Privacy, permissions, components, terms, help and contributor pages use in-app HTML, rendered in an Android/iOS WebView or embedded Web document. The app handles document navigation; GitHub and email links open in the browser or mail client only when selected.

## Edit and generate

- `config.json`: operator, contact email and policy version date. Distributors supply their actual details.
- `community.json`: public repository, maintainers and contributions displayed with consent.
- [Generator](../tools/build_policy_pages.py): policy text and styles.

Run from the repository root:

~~~sh
python3 tools/build_policy_pages.py
python3 -m unittest discover -s tools/tests
~~~

Outputs are `assets/legal/*.html` and `lib/services/policy_pages.g.dart`. Commit them together; do not edit them directly. Native and Web views share the generated content. When WebView is unavailable, the same content appears as selectable text.

Update the text and version when data purposes or permissions change, and renew consent where necessary. Adapt templates to your distribution; contributions follow the [maintenance policy](../CONTRIBUTING.en.md#owner-maintained-paths).
