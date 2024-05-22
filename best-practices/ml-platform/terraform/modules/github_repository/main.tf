# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "github_repository" "repo" {
  allow_merge_commit     = var.allow_merge_commit
  allow_rebase_merge     = var.allow_rebase_merge
  allow_squash_merge     = var.allow_squash_merge
  auto_init              = var.auto_init
  delete_branch_on_merge = var.delete_branch_on_merge
  description            = var.description
  has_issues             = var.has_issues
  has_projects           = var.has_projects
  has_wiki               = var.has_wiki
  name                   = var.name
  visibility             = var.visibility
  vulnerability_alerts   = var.vulnerability_alerts
}

resource "github_branch" "branch" {
  for_each = toset(var.branches.names)

  branch     = each.value
  repository = github_repository.repo.name
}

resource "github_branch_default" "branch" {
  depends_on = [
    github_branch.branch
  ]

  branch     = var.branches.default
  repository = github_repository.repo.name
}
