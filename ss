Short Description
Provision PIM roles through SailPoint with automatic creation of secondary account
Description
This change provisions PIM roles through SailPoint, creating a secondary account and assigning the requested role in real time. It also removes the access at the time of termination or when removal is requested. The change is for existing users in production who request PIM roles.
Justification
At present, granting PIM roles is a manual process that requires effort from the team for each request. With this change, the provisioning will be automated through SailPoint, so the secondary account is created and the role is assigned as soon as the request is approved. It also removes the access at the time of termination or when removal is requested, which strengthens our security governance. This reduces the turnaround time for users and the manual workload on the team. Without this change, provisioning will continue to be manual and access delivery will remain slow.
Implementation Plan

Take backup of the source.
Disable the source.
Promote the rule from development to production.
Create the access profile.
Create the role.

Risk and Impact Analysis
Risk level is High. This change is performed in production on existing users. The impact of SailPoint is to create the secondary account and assign the requested role in real time, which reduces the downtime of the manual work.
Backout Plan
Revert the cloud rule.
Test Plan
Testing will be performed on one existing user and one new user. For both, confirm that SailPoint creates the secondary account and assigns the requested PIM role correctly and in real time. Confirm the role and entitlements match the request, and obtain sign off from the IAM team once both cases pass.
