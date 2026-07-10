import { z } from 'zod'

export const odpSchema = z.object({
  id: z.number().optional(),
  parent_id: z.number().optional().nullable(),
  odc_id: z.number().optional().nullable(),
  odc_name: z.string().optional().nullable(),
  parent_odp_name: z.string().optional().nullable(),
  router_id: z.string().optional(),
  name: z.string().min(1, 'Nama ODP wajib diisi'),
  location: z.string().min(1, 'Lokasi wajib diisi'),
  maps_link: z.string().optional().nullable(),
  lat: z.number().optional().nullable(),
  lng: z.number().optional().nullable(),
  type: z.enum(['splitter', 'ratio']),
  splitter_type: z.string().optional().nullable(),
  ratio_used: z.number().optional().nullable(),
  ratio_total: z.number().optional().nullable(),
  gpon_type: z.string().optional().nullable(),
  rx_power: z.string().optional().nullable(),
  odp_type_flag: z.string().optional().nullable(),
  total_users: z.number().optional(),
  users_list: z.array(z.object({
    username: z.string(),
    redaman: z.string().optional(),
    odp_port: z.number().optional().nullable(),
  })).optional(),
  cable_color_id: z.number().optional().nullable(),
  cable_color_name: z.string().optional().nullable(),
  cable_color_code: z.string().optional().nullable(),
  core_number: z.number().optional().nullable(),
  capacity: z.number().optional().nullable(),
})

export type ODP = z.infer<typeof odpSchema>
