import { z } from 'zod'

export const odcSchema = z.object({
  id: z.number().optional(),
  router_id: z.string().optional(),
  name: z.string().min(1, 'Nama ODC wajib diisi'),
  location: z.string().min(1, 'Lokasi wajib diisi'),
  maps_link: z.string().optional().nullable(),
  lat: z.number().optional().nullable(),
  lng: z.number().optional().nullable(),
  capacity: z.number().optional().nullable(),
  notes: z.string().optional().nullable(),
  cable_color_id: z.number().optional().nullable(),
  cable_color_name: z.string().optional().nullable(),
  cable_color_code: z.string().optional().nullable(),
  core_number: z.number().optional().nullable(),
})

export type ODC = z.infer<typeof odcSchema>
