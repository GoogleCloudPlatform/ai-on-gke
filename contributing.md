# How to Contribute

We would love to accept your patches and contributions to this project.

## Before you begin

### Sign our Contributor License Agreement

Contributions to this project must be accompanied by a
[Contributor License Agreement](https://cla.developers.google.com/about) (CLA).
You (or your employer) retain the copyright to your contribution; this simply
gives us permission to use and redistribute your contributions as part of the
project.

If you or your current employer have already signed the Google CLA (even if it
was for a different project), you probably don't need to do it again.

Visit <https://cla.developers.google.com/> to see your current agreements or to
sign a new one.

### Review our Community Guidelines

This project follows [Google's Open Source Community
Guidelines](https://opensource.google/conduct/).

## Contribution process

### Code Reviews

All submissions, including submissions by project members, require review. We 
use [GitHub pull requests](https://docs.github.com/articles/about-pull-requests)
for this purpose.

After creating a pull request, a collaborator needs to add `/gcbrun` as a comment
to trigger CI for the PR, which includes the CloudBuild triggered e2e test
`pr-review-trigger` and `pr-review-trigger-ap-clusters` as shown below. 
![image](https://github.com/user-attachments/assets/6a759456-e1dd-4a3b-95da-84c9f2b8b053)

If any of the builds fail, you can find the link to the build log for these triggers at
the bottom of the details page by clicking `Details` link. 


