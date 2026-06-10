Short Description
Update SailPoint workflow to add additional email recipient for Australia team
Description
This change updates the SailPoint workflow to add an additional team member as an email recipient for Australia. At present, the email is sent only to the manager. After this change, the additional team member will also receive the email. The change is for the existing workflow in production.
Justification
At present, the workflow sends the email only to the manager, so the Australia team member does not get the notification. With this change, the additional team member will also be included as a recipient, which keeps the right people informed and improves the visibility for the Australia team.
Implementation Plan

Disable the workflow.
Take backup of the workflow.
Update the workflow with the additional recipient.

Risk and Impact Analysis
Risk level is Low. This change is only to update the email recipient in the workflow and does not change any provisioning or access.
Backout Plan
Re-upload the workflow from the backup.
Test Plan
Testing will be performed on an existing contractor. Validate that the email has been sent out from SailPoint to the additional recipient, and confirm with the Australia team that they have received it.
