# Independent distribution and templates

[简体中文](README.md) | [English](README.en.md)

This directory provides signing examples, local policy pages, checklists and copyright-document templates for developers preparing a distribution. Adapt them to your build and target market. Templates do not establish registration, filing or store approval.

## Fill in before distribution

| Item | Location and requirements |
| --- | --- |
| Operator, contact and policy version | [config.json](../../policies/config.json); fill in actual details. See [local policy pages](../../policies/README.en.md) to edit and generate the documents. |
| App name, icon, identifiers and version | `pubspec.yaml` and Android/iOS projects; use your own identity and assets. |
| Signing and store accounts | [Android](../android-release.md), [iOS](../ios-setup.md); use your own accounts and certificates. |
| Listing, screenshots, privacy disclosures | [Listing template](templates/store-listing.md); every statement must match the shipped build. |
| Copyright application and manual | [Application fields](templates/copyright-application.md), [metadata](templates/copyright-metadata.example.json), [manual](templates/software-description.md). |
| Fork repository and contributor display | `policies/community.json`, `.github/contributors-ownership.json`, CODEOWNERS and ruleset templates; configure your own governance while retaining upstream copyright notices. |

Keep completed personal/company records, certificates, applications and exports outside Git or in the ignored `docs/software-copyright/` directory. Leave the shared templates blank. Fill in the contact email and other placeholders before distribution.

## Generate copyright materials

Copy the three copyright templates into `docs/software-copyright/`, rename the metadata file to `copyright-metadata.json`, then complete the metadata and manual. Distinguish upstream code, your additions and third-party assets. Do not claim the entire fork as original work or treat MIT as a copyright assignment. Publication status must reflect actual public availability; open source does not mean “unpublished”.

Install Python `reportlab` and provide a licensed TTF font with Chinese coverage:

~~~sh
python3 tools/build_software_copyright_materials.py \
  --metadata docs/software-copyright/copyright-metadata.json \
  --description docs/software-copyright/software-description.md \
  --font /path/to/licensed-cjk.ttf
~~~

Outputs are `docs/software-copyright/source-materials.pdf` and `software-description.pdf`. The generator uses 50 source lines per page: the first and last 30 pages when longer than 60 pages, otherwise the full listing. It assists formatting, not eligibility or compliance with current filing requirements. Review completeness and layout before use.

Complete the [release checklist](../release-checklist.md) and verify current market and jurisdiction requirements. Code uses MIT; each distributor handles their own data practices, asset rights, filings and user support. See [legal and licensing](../legal.md).
