import { createFileRoute } from '@tanstack/react-router'
import { ODPRatioCalculator } from '@/features/odp/ratio-calculator'

export const Route = createFileRoute('/_authenticated/odp/ratio-calculator')({
  component: ODPRatioCalculator,
})
