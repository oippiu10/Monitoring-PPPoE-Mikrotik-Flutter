import { createFileRoute } from '@tanstack/react-router'
import { ActivityLogs } from '@/features/system-tools/activity-logs'

export const Route = createFileRoute('/_authenticated/logs')({
  component: ActivityLogs,
})
