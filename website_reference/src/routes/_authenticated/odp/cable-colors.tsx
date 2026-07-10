import { createFileRoute } from '@tanstack/react-router'
import CableColorsPage from '@/features/cable-colors/index'

export const Route = createFileRoute('/_authenticated/odp/cable-colors')({
  component: CableColorsPage,
})
