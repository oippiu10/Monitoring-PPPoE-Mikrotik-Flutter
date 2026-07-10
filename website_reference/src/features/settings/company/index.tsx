import { zodResolver } from '@hookform/resolvers/zod'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Loader2, Building, Globe, MapPin, Phone, Mail, Image, Tag } from 'lucide-react'
import { ContentSection } from '../components/content-section'
import { useAuthStore } from '@/stores/auth-store'

const companyFormSchema = z.object({
  isp_name: z.string().min(1, { message: 'Nama Perusahaan wajib diisi' }),
  isp_tagline: z.string().optional(),
  isp_address: z.string().optional(),
  isp_phone: z.string().optional(),
  isp_email: z.string().email({ message: 'Format email tidak valid' }).or(z.string().length(0)),
  isp_logo: z.string().url({ message: 'Harus berupa URL gambar yang valid' }).or(z.string().length(0)),
})

type CompanyFormValues = z.infer<typeof companyFormSchema>

export function SettingsCompany() {
  const queryClient = useQueryClient()
  const role = useAuthStore((state) => state.auth.user?.role?.toLowerCase() || '')
  const canEdit = ['admin', 'administrator', 'super_admin', 'super admin', 'superadministrator'].includes(role)

  // Fetch current settings
  const { data: settings, isLoading } = useQuery({
    queryKey: ['web-settings'],
    queryFn: async () => {
      const res = await api.get('/web_settings.php')
      return res.data.data || {}
    }
  })

  const form = useForm<CompanyFormValues>({
    resolver: zodResolver(companyFormSchema),
    values: {
      isp_name: settings?.isp_name || '',
      isp_tagline: settings?.isp_tagline || '',
      isp_address: settings?.isp_address || '',
      isp_phone: settings?.isp_phone || '',
      isp_email: settings?.isp_email || '',
      isp_logo: settings?.isp_logo || '',
    },
  })

  const mutation = useMutation({
    mutationFn: async (values: CompanyFormValues) => {
      const res = await api.post('/web_settings.php', {
        settings: values
      })
      return res.data
    },
    onSuccess: () => {
      toast.success('Pengaturan profil perusahaan berhasil disimpan')
      queryClient.invalidateQueries({ queryKey: ['web-settings'] })
    },
    onError: (error: any) => {
      toast.error(error.response?.data?.message || 'Gagal menyimpan pengaturan')
    }
  })

  function onSubmit(data: CompanyFormValues) {
    mutation.mutate(data)
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-48">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
      </div>
    )
  }

  return (
    <ContentSection
      title='Company Settings'
      desc='Kelola data profil perusahaan, logo, alamat, dan kontak informasi untuk kebutuhan invoice dan laporan.'
    >
      <Card className="border-none shadow-md bg-card/50 backdrop-blur-xl">
        <CardHeader>
          <CardTitle className="text-primary flex items-center gap-2">
            <Building className="w-5 h-5" />
            Profil Perusahaan (ISP)
          </CardTitle>
          <CardDescription>
            Konfigurasikan informasi identitas bisnis Anda. Informasi ini akan dicetak pada bukti pembayaran pelanggan.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className='space-y-6'>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name='isp_name'
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="flex items-center gap-2">
                        <Globe className="w-4 h-4 text-muted-foreground" />
                        Nama Perusahaan / ISP
                      </FormLabel>
                      <FormControl>
                        <Input placeholder='Contoh: WiFiKu Net' disabled={!canEdit} {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name='isp_tagline'
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="flex items-center gap-2">
                        <Tag className="w-4 h-4 text-muted-foreground" />
                        Tagline Perusahaan
                      </FormLabel>
                      <FormControl>
                        <Input placeholder='Contoh: Internet Cepat Tanpa Batas' disabled={!canEdit} {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              <FormField
                control={form.control}
                name='isp_address'
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="flex items-center gap-2">
                      <MapPin className="w-4 h-4 text-muted-foreground" />
                      Alamat Lengkap
                    </FormLabel>
                    <FormControl>
                      <Textarea placeholder='Jl. Kemerdekaan No. 45, Jakarta Pusat' disabled={!canEdit} {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name='isp_phone'
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="flex items-center gap-2">
                        <Phone className="w-4 h-4 text-muted-foreground" />
                        No. Telepon / WhatsApp
                      </FormLabel>
                      <FormControl>
                        <Input placeholder='Contoh: 081234567890' disabled={!canEdit} {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name='isp_email'
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="flex items-center gap-2">
                        <Mail className="w-4 h-4 text-muted-foreground" />
                        Alamat Email
                      </FormLabel>
                      <FormControl>
                        <Input placeholder='Contoh: info@wifiku.net' disabled={!canEdit} {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              <FormField
                control={form.control}
                name='isp_logo'
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="flex items-center gap-2">
                      <Image className="w-4 h-4 text-muted-foreground" />
                      URL Logo Perusahaan
                    </FormLabel>
                    <FormControl>
                      <Input placeholder='Contoh: https://domain.com/logo.png' disabled={!canEdit} {...field} />
                    </FormControl>
                    <FormDescription>
                      Masukkan URL link ke file gambar logo Anda (format PNG transparan direkomendasikan).
                    </FormDescription>
                    {field.value && (
                      <div className="mt-2 p-3 border border-dashed rounded-lg flex items-center justify-center bg-muted/40">
                        <img src={field.value} alt="Preview Logo" className="h-12 object-contain" onError={(e) => {
                          (e.target as HTMLImageElement).src = 'https://placehold.co/150x50?text=Invalid+Image+URL'
                        }} />
                      </div>
                    )}
                    <FormMessage />
                  </FormItem>
                )}
              />

              {canEdit ? (
                <Button type='submit' disabled={mutation.isPending}>
                  {mutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Simpan Perubahan
                </Button>
              ) : (
                <p className='text-xs text-muted-foreground'>Mode baca saja. Hanya administrator yang dapat mengubah data perusahaan.</p>
              )}
            </form>
          </Form>
        </CardContent>
      </Card>
    </ContentSection>
  )
}
