import { z } from 'zod'

export const cableColorSchema = z.object({
  id: z.number().optional(),
  router_id: z.string().optional(),
  name: z.string().min(1, 'Nama warna kabel wajib diisi'),
  color_code: z.string().min(4, 'Kode warna wajib diisi (minimal 4 karakter)'),
})

export type CableColor = z.infer<typeof cableColorSchema>
