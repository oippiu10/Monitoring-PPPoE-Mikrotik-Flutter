import { createFileRoute } from '@tanstack/react-router'
import ODCPage from '@/features/odc'

export const Route = createFileRoute('/_authenticated/odp/odc')({
  component: ODCPage,
})
