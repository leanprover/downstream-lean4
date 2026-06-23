import { Octokit, Repo } from "./util";

const MARKER = "ybVeuCO3cIRWlSWmC/cEvg2Na4yzOwEa";

export interface StatusMessageOptions {
  octo: Octokit;
  appSlug: string;
  repo: Repo;
  issueNumber: number;
  body: string;
  marker?: string;
  final?: boolean;
}

/**
 * Post a status message on a PR, or update an existing one in-place.
 *
 * Embeds a marker in the message as HTML comment so it can be found again
 * later. On a final status update, you can omit the marker so any new status
 * messages are posted as new, separate messages.
 */
export async function postOrUpdateStatus(
  options: StatusMessageOptions,
): Promise<void> {
  const {
    octo,
    appSlug,
    repo,
    issueNumber,
    body,
    marker = MARKER,
    final = false,
  } = options;

  // Find existing comment
  const login = `${appSlug}[bot]`;
  const comments = await octo.paginate(octo.rest.issues.listComments, {
    ...repo,
    issue_number: issueNumber,
    per_page: 100,
  });
  const comment = comments.find(
    (c) => c.user?.login === login && c.body?.includes(marker),
  );

  // Post new or update existing comment
  const fullBody = final ? body : `${body}\n\n<!-- marker: ${marker} -->`;
  if (comment === undefined) {
    await octo.rest.issues.createComment({
      ...repo,
      issue_number: issueNumber,
      body: fullBody,
    });
  } else {
    await octo.rest.issues.updateComment({
      ...repo,
      comment_id: comment.id,
      body: fullBody,
    });
  }
}
