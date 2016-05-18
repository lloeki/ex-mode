# Ex-Mode Contributing Guidelines

Current Maintainers:

- [@jazzpi](https://github.com/jazzpi)
- [@LongLiveCHIEF](https://github.com/LongLiveCHIEF)

This project is accepting new maintainers. Interested parties should

1. Open a new issue, titled: `New Maintainer Request`
2. Assign the issue to [@lloeki](https://github.com/lloeki)
3. The last line of your request should `/cc @jazzpi @LongLiveCHIEF`

## Pull Requests

- If the PR *fixes* or should result in the closure of any issues, use the `fixes #` or `closes #` syntax to ensure issue will
close when your PR is merged
- All pull-requests that fix a bug or add a new feature *must* have accompanying tests before they will be merged. If you want
to speed up the merge of your PR, please contribute these tests
 - *note*: if you submit a PR but are unsure how to write tests, please begin your PR title with `[needs tests]`
- Please use the [pull request template](PULL_REQUEST_TEMPLATE.md) as a guide for submitting your PR.
- Include a `/cc` for @LongLiveCHIEF and @jazzpi the current maintainers

## Issues

- Be aware of the responsibilities of `ex-mode` vs `vim-mode`
- If you have identified a bug we would welcome any Pull Requests that either:
 - Fix the issue
 - Create failing tests to confirm the bug
