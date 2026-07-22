export interface BuildReportPhase {
  success: boolean | null; // null == skipped
  duration: number | null;
}

export interface BuildReportRepo {
  name: string;
  critical: boolean;
  green: boolean;
  build: BuildReportPhase;
  test: BuildReportPhase;
  lint: BuildReportPhase;
}

export interface BuildReport {
  commit_sha: string;
  commit_message: string;
  commit_date: string;
  toolchain: string;
  green: boolean;
  repos: BuildReportRepo[];
}

export type StatusReport = Record<string, boolean>;
