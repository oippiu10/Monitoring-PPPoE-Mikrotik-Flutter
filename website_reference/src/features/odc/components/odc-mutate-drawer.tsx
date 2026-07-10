import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { api } from '@/lib/api'
import { useRouterStore } from '@/stores/router-store'
import { odcSchema, type ODC } from '../data/schema'
import { FiberCorePicker } from '@/components/fiber-core-picker'

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { MapPicker } from '@/components/map-picker'
import { Link2, MapPin } from 'lucide-react'
import { useState } from 'react'

interface Props {
  isOpen: boolean
  onClose: () => void
  odc?: ODC | null
}

export function ODCMutateDialog({ isOpen, onClose, odc }: Props) {
  const isEditing = !!odc
  const { activeRouter } = useRouterStore()
  const queryClient = useQueryClient()
  const [isMapPickerOpen, setIsMapPickerOpen] = useState(false)


  const form = useForm<ODC>({
    resolver: zodResolver(odcSchema) as any,
    defaultValues: {
      name: '',
      location: '',
      maps_link: '',
      lat: null,
      lng: null,
      capacity: 12,
      notes: '',
      cable_color_id: null,
      core_number: null,
    },
  })

  useEffect(() => {
    if (isOpen) {
      if (odc) {
        form.reset({
          ...odc,
          lat: odc.lat !== null && odc.lat !== undefined ? Number(odc.lat) : null,
          lng: odc.lng !== null && odc.lng !== undefined ? Number(odc.lng) : null,
          capacity: odc.capacity || 12,
          notes: odc.notes || '',
          cable_color_id: odc.cable_color_id !== null && odc.cable_color_id !== undefined ? Number(odc.cable_color_id) : null,
          core_number: odc.core_number !== null && odc.core_number !== undefined ? Number(odc.core_number) : null,
        })
      } else {
        form.reset({
          name: '',
          location: '',
          maps_link: '',
          lat: null,
          lng: null,
          capacity: 12,
          notes: '',
          cable_color_id: null,
          core_number: null,
        })
      }
    }
  }, [isOpen, odc, form])

  const mutation = useMutation({
    mutationFn: async (data: ODC) => {
      const payload = {
        ...data,
        router_id: activeRouter?.id,
      }
      if (isEditing && odc) {
        return api.put('/odc.php', { ...payload, id: odc.id })
      }
      return api.post('/odc.php', payload)
    },
    onSuccess: () => {
      toast.success(isEditing ? 'ODC berhasil diperbarui' : 'ODC berhasil ditambahkan')
      queryClient.invalidateQueries({ queryKey: ['odcs'] })
      onClose()
    },
    onError: (err: any) => {
      toast.error(err.response?.data?.message || 'Gagal menyimpan ODC')
    },
  })

  const onSubmit = (data: ODC) => {
    mutation.mutate(data)
  }

  // Parse maps link to fill coordinates automatically
  const handleMapsLinkChange = (url: string) => {
    form.setValue('maps_link', url)
    if (!url) return

    // Regex untuk format Google Maps (@lat,lng)
    const regex1 = /@(-?\d+\.\d+),(-?\d+\.\d+)/
    const match1 = url.match(regex1)
    if (match1) {
      form.setValue('lat', parseFloat(match1[1]))
      form.setValue('lng', parseFloat(match1[2]))
      toast.success('Koordinat terdeteksi dari Link Maps')
      return
    }

    // Regex untuk format q=lat,lng
    const regex2 = /q=(-?\d+\.\d+),(-?\d+\.\d+)/
    const match2 = url.match(regex2)
    if (match2) {
      form.setValue('lat', parseFloat(match2[1]))
      form.setValue('lng', parseFloat(match2[2]))
      toast.success('Koordinat terdeteksi dari Link Maps')
      return
    }
  }

  return (
    <>
      <Dialog open={isOpen} onOpenChange={onClose}>
        <DialogContent className='sm:max-w-[450px] p-0 overflow-hidden border-none rounded-3xl shadow-2xl bg-white dark:bg-slate-900'>
          <DialogHeader className='px-6 pt-6 pb-4 bg-linear-to-r from-amber-500/10 to-transparent'>
            <DialogTitle className='text-lg font-black uppercase tracking-wider text-amber-600 dark:text-amber-400'>
              {isEditing ? 'Edit ODC' : 'Tambah ODC'}
            </DialogTitle>
          </DialogHeader>

          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className='space-y-4 px-6 pb-6'>
              <ScrollArea className='h-[450px] pr-2'>
                <div className='space-y-4 pt-1'>
                  <FormField
                    control={form.control}
                    name='name'
                    render={({ field }) => (
                      <FormItem className="space-y-1">
                        <FormLabel className="text-xs font-bold">Nama ODC</FormLabel>
                        <FormControl>
                          <Input placeholder='Contoh: ODC-PUSAT-01' {...field} className="h-8 text-xs font-semibold" />
                        </FormControl>
                        <FormMessage className="text-[10px]" />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name='capacity'
                    render={({ field }) => (
                      <FormItem className="space-y-1">
                        <FormLabel className="text-xs font-bold">Kapasitas (Port)</FormLabel>
                        <Select 
                          value={field.value ? String(field.value) : ''} 
                          onValueChange={(val) => field.onChange(Number(val))}
                        >
                          <FormControl>
                            <SelectTrigger className="h-8 text-xs font-semibold">
                              <SelectValue placeholder="Pilih Kapasitas" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            <SelectItem value="2">2 Port</SelectItem>
                            <SelectItem value="4">4 Port</SelectItem>
                            <SelectItem value="8">8 Port</SelectItem>
                            <SelectItem value="16">16 Port</SelectItem>
                            <SelectItem value="32">32 Port</SelectItem>
                          </SelectContent>
                        </Select>
                        <FormMessage className="text-[10px]" />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name='location'
                    render={({ field }) => (
                      <FormItem className="space-y-1">
                        <FormLabel className="text-xs font-bold">Lokasi / Alamat</FormLabel>
                        <FormControl>
                          <Input placeholder='Contoh: Jl. Raya Pekalongan No. 12' {...field} className="h-8 text-xs font-semibold" />
                        </FormControl>
                        <FormMessage className="text-[10px]" />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name='maps_link'
                    render={({ field }) => (
                      <FormItem className="space-y-1">
                        <FormLabel className="text-xs font-bold flex items-center gap-1">
                          <Link2 className="h-3.5 w-3.5 text-amber-500" />
                          Link Google Maps
                        </FormLabel>
                        <FormControl>
                          <Input 
                            placeholder='Paste link Google Maps untuk auto-fill koordinat' 
                            {...field} 
                            value={field.value || ''} 
                            onChange={e => handleMapsLinkChange(e.target.value)}
                            className="h-8 text-xs font-semibold" 
                          />
                        </FormControl>
                        <FormMessage className="text-[10px]" />
                      </FormItem>
                    )}
                  />

                  <div className='grid grid-cols-2 gap-2'>
                    <FormField
                      control={form.control}
                      name='lat'
                      render={({ field }) => (
                        <FormItem className="space-y-1">
                          <FormLabel className="text-xs font-bold">Latitude</FormLabel>
                          <FormControl>
                            <Input 
                              type='number' 
                              step='any' 
                              placeholder='-6.123456' 
                              {...field} 
                              value={field.value !== null && field.value !== undefined ? field.value : ''} 
                              onChange={e => field.onChange(e.target.value === '' ? null : parseFloat(e.target.value))}
                              className="h-8 text-xs font-semibold" 
                            />
                          </FormControl>
                          <FormMessage className="text-[10px]" />
                        </FormItem>
                      )}
                    />

                    <FormField
                      control={form.control}
                      name='lng'
                      render={({ field }) => (
                        <FormItem className="space-y-1">
                          <FormLabel className="text-xs font-bold">Longitude</FormLabel>
                          <FormControl>
                            <Input 
                              type='number' 
                              step='any' 
                              placeholder='106.123456' 
                              {...field} 
                              value={field.value !== null && field.value !== undefined ? field.value : ''} 
                              onChange={e => field.onChange(e.target.value === '' ? null : parseFloat(e.target.value))}
                              className="h-8 text-xs font-semibold" 
                            />
                          </FormControl>
                          <FormMessage className="text-[10px]" />
                        </FormItem>
                      )}
                    />
                  </div>

                  <Button 
                    type='button' 
                    variant='outline' 
                    size='sm' 
                    onClick={() => setIsMapPickerOpen(true)}
                    className="w-full h-8 text-xs font-bold border-amber-200 hover:bg-amber-50 dark:border-amber-900/50"
                  >
                    <MapPin className='mr-1.5 h-3.5 w-3.5 text-amber-500' />
                    Pilih Titik di Peta
                  </Button>

                  <FormField
                    control={form.control}
                    name='notes'
                    render={({ field }) => (
                      <FormItem className="space-y-1">
                        <FormLabel className="text-xs font-bold">Catatan / Keterangan</FormLabel>
                        <FormControl>
                          <Input placeholder='Opsional' {...field} value={field.value || ''} className="h-8 text-xs font-semibold" />
                        </FormControl>
                        <FormMessage className="text-[10px]" />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name='core_number'
                    render={({ field }) => (
                      <FormItem className="space-y-1">
                        <FiberCorePicker
                          value={field.value as number | null}
                          onChange={(val) => field.onChange(val)}
                          onCableColorChange={(colorId) => form.setValue('cable_color_id', colorId)}
                          label="Nomor Core (Uplink/Backbone)"
                        />
                        <FormMessage className="text-[10px]" />
                      </FormItem>
                    )}
                  />

                </div>
              </ScrollArea>

              <div className='flex justify-end gap-2 pt-2 border-t dark:border-slate-800'>
                <Button type='button' variant='ghost' size='sm' onClick={onClose} className="h-9 text-xs font-bold">
                  Batal
                </Button>
                <Button type='submit' size='sm' disabled={mutation.isPending} className="h-9 text-xs font-bold bg-amber-600 hover:bg-amber-700 text-white">
                  {mutation.isPending ? 'Menyimpan...' : 'Simpan'}
                </Button>
              </div>
            </form>
          </Form>
        </DialogContent>
      </Dialog>

      <MapPicker
        isOpen={isMapPickerOpen}
        onClose={() => setIsMapPickerOpen(false)}
        onSelect={(lat, lng) => {
          form.setValue('lat', lat)
          form.setValue('lng', lng)
          toast.success('Koordinat terpilih dari peta')
        }}
        initialLat={form.getValues('lat') || -6.889}
        initialLng={form.getValues('lng') || 109.675}
      />
    </>
  )
}
