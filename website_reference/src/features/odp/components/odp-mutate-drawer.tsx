'use no memo'

import { useEffect } from 'react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Link2, MapPin, ChevronsUpDown, Check } from 'lucide-react'
import { toast } from 'sonner'
import { useRouterStore } from '@/stores/router-store'
import { api } from '@/lib/api'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import {
  Command,
  CommandInput,
  CommandList,
  CommandEmpty,
  CommandGroup,
  CommandItem,
} from '@/components/ui/command'
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
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'
import { ScrollArea } from '@/components/ui/scroll-area'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  SelectGroup,
  SelectLabel,
  SelectSeparator,
} from '@/components/ui/select'
import { MapPicker } from '@/components/map-picker'
import { odpSchema, type ODP } from '../data/schema'
import { getFiberColors } from '@/lib/fiber-color'
import { FiberCorePicker } from '@/components/fiber-core-picker'

interface Props {
  isOpen: boolean
  onClose: () => void
  odp?: ODP | null
}

export function ODPMutateDialog({ isOpen, onClose, odp }: Props) {
  const isEditing = !!odp
  const { activeRouter } = useRouterStore()
  const queryClient = useQueryClient()
  const [isMapPickerOpen, setIsMapPickerOpen] = useState(false)
  const [isUpstreamOpen, setIsUpstreamOpen] = useState(false)
  const [suffix, setSuffix] = useState('')
  const [prefix, setPrefix] = useState('ODP')

  const { data: odpList } = useQuery<ODP[]>({
    queryKey: ['odps', activeRouter?.id],
    queryFn: async () => {
      const res = await api.get('/odp.php', {
        params: { router_id: activeRouter?.id },
      })
      return res.data.data || []
    },
    enabled: !!activeRouter && isOpen,
  })

  const { data: odcList } = useQuery<any[]>({
    queryKey: ['odcs', activeRouter?.id],
    queryFn: async () => {
      const res = await api.get('/odc.php', {
        params: { router_id: activeRouter?.id },
      })
      return res.data.data || []
    },
    enabled: !!activeRouter && isOpen,
  })



  const form = useForm<ODP>({
    resolver: zodResolver(odpSchema),
    defaultValues: {
      name: '',
      parent_id: null,
      odc_id: null,
      location: '',
      maps_link: '',
      lat: null,
      lng: null,
      type: 'splitter',
      splitter_type: '1:8',
      ratio_used: 0,
      ratio_total: 0,
      gpon_type: 'GPON',
      rx_power: '',
      odp_type_flag: 'ratio',
      cable_color_id: null,
      core_number: null,
    },
  })

  // Sinkronisasi Suffix saat Edit dibuka
  useEffect(() => {
    if (isOpen) {
      if (odp) {
        let upstreamName = ''
        if (odp.odc_id) {
          const foundOdc = odcList?.find((o) => o.id === odp.odc_id)
          if (foundOdc) {
            upstreamName = foundOdc.name
          } else if (odp.odc_name) {
            upstreamName = odp.odc_name
          }
        } else if (odp.parent_id) {
          const foundParent = odpList?.find((o) => o.id === odp.parent_id)
          if (foundParent) {
            upstreamName = foundParent.name
          }
        }

        // Deteksi prefix dari nama ODP yang ada
        let detectedPrefix = 'ODP'
        let defaultSuffix = odp.name || ''
        
        if (upstreamName && defaultSuffix.endsWith(`-${upstreamName}`)) {
          // Format baru: PREFIX-SUFFIX-UPSTREAM
          const beforeUpstream = defaultSuffix.substring(0, defaultSuffix.lastIndexOf(`-${upstreamName}`))
          const dashIdx = beforeUpstream.indexOf('-')
          if (dashIdx !== -1) {
            detectedPrefix = beforeUpstream.substring(0, dashIdx)
            defaultSuffix = beforeUpstream.substring(dashIdx + 1)
          } else {
            detectedPrefix = beforeUpstream || 'ODP'
            defaultSuffix = ''
          }
        } else if (upstreamName && defaultSuffix.includes(`-${upstreamName}-`)) {
          // Format lama: PREFIX-UPSTREAM-SUFFIX
          const beforeUpstream = defaultSuffix.substring(0, defaultSuffix.indexOf(`-${upstreamName}-`))
          detectedPrefix = beforeUpstream || 'ODP'
          defaultSuffix = defaultSuffix.substring(defaultSuffix.indexOf(`-${upstreamName}-`) + `-${upstreamName}-`.length)
        } else {
          // Format: PREFIX-SUFFIX (tanpa upstream)
          const dashIdx = defaultSuffix.indexOf('-')
          if (dashIdx !== -1) {
            detectedPrefix = defaultSuffix.substring(0, dashIdx)
            defaultSuffix = defaultSuffix.substring(dashIdx + 1)
          }
        }
        setPrefix(detectedPrefix)
        setSuffix(defaultSuffix)

        form.reset({
          ...odp,
          lat:
            odp.lat !== null && odp.lat !== undefined ? Number(odp.lat) : null,
          lng:
            odp.lng !== null && odp.lng !== undefined ? Number(odp.lng) : null,
          parent_id: odp.parent_id || null,
          odc_id: odp.odc_id || null,
          gpon_type: odp.gpon_type || 'GPON',
          rx_power: odp.rx_power || '',
          odp_type_flag: odp.odp_type_flag || 'ratio',
          cable_color_id:
            odp.cable_color_id !== null && odp.cable_color_id !== undefined
              ? Number(odp.cable_color_id)
              : null,
          core_number:
            odp.core_number !== null && odp.core_number !== undefined
              ? Number(odp.core_number)
              : null,
        })
      } else {
        setPrefix('ODP')
        setSuffix('')
        form.reset({
          name: '',
          parent_id: null,
          odc_id: null,
          location: '',
          maps_link: '',
          lat: null,
          lng: null,
          type: 'splitter',
          splitter_type: '1:8',
          ratio_used: 0,
          ratio_total: 0,
          gpon_type: 'GPON',
          rx_power: '',
          odp_type_flag: 'ratio',
          cable_color_id: null,
          core_number: null,
        })
      }
    }
  }, [isOpen, odp, form, odcList, odpList])

  // Sinkronisasi Gabungan Nama ODP
  const currentOdcId = form.watch('odc_id')
  const currentParentId = form.watch('parent_id')

  useEffect(() => {
    const finalName = suffix ? `${prefix}-${suffix}` : prefix
    form.setValue('name', finalName, { shouldDirty: true, shouldValidate: true })
  }, [suffix, prefix, form])

  const mutation = useMutation({
    mutationFn: async (values: ODP) => {
      if (isEditing) {
        const res = await api.put('/odp.php', values)
        return res.data
      } else {
        const res = await api.post('/odp.php', {
          ...values,
          router_id: activeRouter?.id,
        })
        return res.data
      }
    },
    onSuccess: (data) => {
      if (data.success) {
        toast.success(
          isEditing ? 'Berhasil memperbarui ODP' : 'Berhasil menambah ODP'
        )
        queryClient.invalidateQueries({ queryKey: ['odps'] })
        onClose()
      } else {
        toast.error(data.message || 'Gagal menyimpan data')
      }
    },
    onError: (error: any) => {
      toast.error(error.response?.data?.message || 'Terjadi kesalahan sistem')
    },
  })

  const onSubmit = (values: ODP) => {
    mutation.mutate({
      ...values,
      odp_type_flag: values.type,
    })
  }

  const parseCoordsFromMaps = (text?: string | null) => {
    if (!text) return null
    const decoded = decodeURIComponent(text)
    const patterns = [
      /@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/,
      /\/place\/(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/,
      /[?&]q=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/,
      /[?&]ll=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/,
      /!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/,
      /^\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\s*$/,
    ]
    for (const pattern of patterns) {
      const match = decoded.match(pattern)
      if (match) {
        const lat = Number(match[1])
        const lng = Number(match[2])
        if (Math.abs(lat) <= 90 && Math.abs(lng) <= 180) return { lat, lng }
      }
    }
    return null
  }

  const fillMapsFromCoords = () => {
    const lat = form.getValues('lat')
    const lng = form.getValues('lng')
    if (lat == null || lng == null) {
      toast.error('Isi latitude dan longitude dulu')
      return
    }
    form.setValue('maps_link', `https://www.google.com/maps?q=${lat},${lng}`, {
      shouldDirty: true,
    })
    toast.success('Link Google Maps dibuat dari koordinat')
  }

  const convertCurrentMapsLink = async () => {
    const link = form.getValues('maps_link')
    if (!link) {
      toast.error('Link Google Maps masih kosong')
      return
    }
    const direct = parseCoordsFromMaps(link)
    if (direct) {
      form.setValue('lat', direct.lat, { shouldDirty: true })
      form.setValue('lng', direct.lng, { shouldDirty: true })
      form.setValue(
        'maps_link',
        `https://www.google.com/maps?q=${direct.lat},${direct.lng}`,
        { shouldDirty: true }
      )
      toast.success('Koordinat ODP berhasil diambil dari link')
      return
    }
    try {
      const res = await api.post('/maps_resolve.php', { url: link })
      if (res.data?.success) {
        const lat = Number(res.data.lat)
        const lng = Number(res.data.lng)
        form.setValue('lat', lat, { shouldDirty: true })
        form.setValue('lng', lng, { shouldDirty: true })
        form.setValue(
          'maps_link',
          `https://www.google.com/maps?q=${lat},${lng}`,
          { shouldDirty: true }
        )
        toast.success('Link ODP berhasil dikonversi ke lat/lng')
      } else {
        toast.error(res.data?.message || 'Gagal membaca koordinat dari link')
      }
    } catch (error: any) {
      toast.error(
        error.response?.data?.message || 'Gagal resolve link Google Maps'
      )
    }
  }

  const type = form.watch('type')

  return (
    <Dialog open={isOpen} onOpenChange={(v) => !v && onClose()}>
      <DialogContent className='sm:max-w-[450px] max-h-[95vh] flex flex-col p-0 overflow-hidden border-none rounded-3xl shadow-2xl bg-white dark:bg-slate-900'>
        <DialogHeader className='px-6 pt-6 pb-4 bg-linear-to-r from-amber-500/10 to-transparent border-b shrink-0'>
          <DialogTitle className='text-sm font-black uppercase tracking-wider text-amber-600 dark:text-amber-400'>
            {isEditing ? 'Edit ODP' : 'Tambah ODP Baru'}
          </DialogTitle>
        </DialogHeader>

        <Form {...form}>
          <form
            id='odp-form'
            onSubmit={form.handleSubmit(onSubmit)}
            className='flex flex-col flex-1 min-h-0'
          >
            <div className='flex-1 overflow-y-auto overflow-x-hidden px-6 custom-scrollbar'>
              <div className='space-y-4 pt-4 pb-6 px-1'>
                {/* 1. SUMBER HULU DI PALING ATAS */}
                <FormField
                  control={form.control}
                  name='parent_id'
                  render={({ field }) => {
                    // eslint-disable-next-line react-hooks/incompatible-library
                    const parentId = form.watch('parent_id')
                    const odcId = form.watch('odc_id')
                    let selectVal = 'none'
                    let selectedLabel = 'Langsung ke Router (Tanpa Hulu)'

                    if (odcId) {
                      selectVal = `odc-${odcId}`
                      const foundOdc = odcList?.find((o) => o.id === odcId)
                      if (foundOdc) {
                        selectedLabel = `ODC - ${foundOdc.name} (${foundOdc.location || 'Tanpa Alamat'})`
                      }
                    } else if (parentId) {
                      selectVal = `odp-${parentId}`
                      const foundOdp = odpList?.find((o) => o.id === parentId)
                      if (foundOdp) {
                        selectedLabel = `ODP - ${foundOdp.name} (${foundOdp.location || 'Tanpa Alamat'})`
                      }
                    }

                    return (
                      <FormItem className='flex flex-col space-y-1'>
                        <FormLabel className='text-xs font-bold text-amber-600 dark:text-amber-400'>
                          1. Sambungkan ke (Pilih Sumber)
                        </FormLabel>
                        <Popover
                          open={isUpstreamOpen}
                          onOpenChange={setIsUpstreamOpen}
                        >
                          <PopoverTrigger asChild>
                            <FormControl>
                              <Button
                                type="button"
                                variant='outline'
                                role='combobox'
                                aria-expanded={isUpstreamOpen}
                                className='h-8 w-full justify-between rounded-md border border-amber-300 dark:border-amber-900 bg-background px-3 py-1 text-xs font-bold hover:bg-accent hover:text-accent-foreground'
                              >
                                <span className='truncate'>
                                  {selectedLabel}
                                </span>
                                <ChevronsUpDown className='ml-2 h-3 w-3 shrink-0 opacity-50' />
                              </Button>
                            </FormControl>
                          </PopoverTrigger>
                          <PopoverContent
                            className='z-9999 w-[var(--radix-popover-trigger-width)] p-0 pointer-events-auto'
                            align='start'
                            side='bottom'
                            sideOffset={4}
                          >
                            <Command>
                              <CommandInput
                                placeholder='Cari ODC atau ODP...'
                                className='h-8 text-xs'
                              />
                              <CommandList className='max-h-[200px] overflow-y-auto pointer-events-auto'>
                                <CommandEmpty className='py-2 text-center text-xs text-muted-foreground'>
                                  Sumber tidak ditemukan.
                                </CommandEmpty>
                                <CommandGroup>
                                  <CommandItem
                                    value='none-router-tanpa-hulu'
                                    onSelect={() => {
                                      form.setValue('parent_id', null)
                                      form.setValue('odc_id', null)
                                      setIsUpstreamOpen(false)
                                    }}
                                    className='flex cursor-pointer items-center justify-between text-xs font-semibold'
                                  >
                                    <span>Langsung ke Router (Tanpa Hulu)</span>
                                    {selectVal === 'none' && (
                                      <Check className='h-3.5 w-3.5 text-primary' />
                                    )}
                                  </CommandItem>
                                </CommandGroup>

                                  {odcList && odcList.length > 0 && (
                                    <CommandGroup heading='Jalur Utama dari ODC (Sumber Utama)'>
                                      {odcList.map((o) => (
                                        <CommandItem
                                          key={o.id}
                                          value={`odc-${o.id} ${o.name} ${o.location || ''}`}
                                          onSelect={() => {
                                            form.setValue('odc_id', o.id)
                                            form.setValue('parent_id', null)
                                            setIsUpstreamOpen(false)
                                          }}
                                          className='flex cursor-pointer items-center justify-between text-xs font-semibold'
                                        >
                                          <span className='truncate'>
                                            {o.name} (
                                            {o.location || 'Tanpa Alamat'})
                                          </span>
                                          {selectVal === `odc-${o.id}` && (
                                            <Check className='h-3.5 w-3.5 text-amber-500' />
                                          )}
                                        </CommandItem>
                                      ))}
                                    </CommandGroup>
                                  )}

                                  {odpList && odpList.length > 0 && (
                                    <CommandGroup heading='Jalur Terusan dari ODP Lain (Diparalel)'>
                                      {odpList
                                        .filter((o) => o.id !== odp?.id)
                                        .map((o) => (
                                          <CommandItem
                                            key={o.id}
                                            value={`odp-${o.id} ${o.name} ${o.location || ''}`}
                                            onSelect={() => {
                                              form.setValue('parent_id', o.id)
                                              form.setValue('odc_id', null)
                                              setIsUpstreamOpen(false)
                                            }}
                                            className='flex cursor-pointer items-center justify-between text-xs font-semibold'
                                          >
                                            <span className='truncate'>
                                              {o.name} (
                                              {o.location || 'Tanpa Alamat'})
                                            </span>
                                            {selectVal === `odp-${o.id}` && (
                                              <Check className='h-3.5 w-3.5 text-blue-500' />
                                            )}
                                          </CommandItem>
                                        ))}
                                    </CommandGroup>
                                  )}
                              </CommandList>
                            </Command>
                          </PopoverContent>
                        </Popover>
                        <FormMessage className='text-[10px]' />
                      </FormItem>
                    )
                  }}
                />

                {/* 2. GRID MODULAR PENAMAAN ODP */}
                <div className='space-y-1.5'>
                  <FormLabel className='text-xs font-bold'>2. Penamaan ODP (Otomatis & Terstruktur)</FormLabel>
                  <div className='grid grid-cols-2 gap-2 min-w-0 max-w-[80%] mx-auto'>
                    {/* Kotak 1: Prefix */}
                    <div className='space-y-1 min-w-0'>
                      <span className='text-[10px] text-muted-foreground block font-semibold text-center'>Prefix</span>
                      <Input
                        value={prefix}
                        onChange={(e) => setPrefix(e.target.value.toUpperCase())}
                        placeholder='ODP'
                        className='h-8 text-xs font-bold text-center border-slate-300 focus-visible:ring-amber-400 min-w-0'
                      />
                    </div>

                    {/* Kotak 2: Suffix (Input Buntut) */}
                    <div className='space-y-1 min-w-0'>
                      <span className='text-[10px] text-muted-foreground block font-semibold text-primary text-center'>Nomor/Buntut</span>
                      <Input
                        value={suffix}
                        onChange={(e) => setSuffix(e.target.value)}
                        placeholder='Contoh: 01'
                        className='h-8 text-xs font-black text-center border-primary focus-visible:ring-primary min-w-0 w-full'
                      />
                    </div>
                  </div>

                  {/* PREVIEW HASIL NAMA AKHIR */}
                  <div className='mt-2 rounded-md bg-slate-50 dark:bg-slate-950 p-2 border border-dashed border-slate-300 dark:border-slate-800 min-h-[32px] flex items-center justify-center'>
                    {(() => {
                      const finalName = suffix ? `${prefix}-${suffix}` : prefix

                      return (
                        <div className='w-full'>
                          <span className='font-black text-amber-600 dark:text-amber-400 text-[11px] tracking-wide block text-center w-full break-words leading-relaxed'>
                            {finalName}
                          </span>
                        </div>
                      )
                    })()}
                  </div>
                </div>

                {type === 'splitter' ? (
                  <div className='grid grid-cols-3 gap-2'>
                    {/* GPON/EPON */}
                    <FormField
                      control={form.control}
                      name='gpon_type'
                      render={({ field }) => (
                        <FormItem className='space-y-1'>
                          <FormLabel className='text-xs'>GPON/EPON</FormLabel>
                          <Select
                            onValueChange={field.onChange}
                            value={field.value || 'GPON'}
                          >
                            <FormControl>
                              <SelectTrigger className='h-8 text-xs'>
                                <SelectValue placeholder='GPON/EPON' />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                              <SelectItem value='GPON' className='text-xs'>
                                GPON
                              </SelectItem>
                              <SelectItem value='EPON' className='text-xs'>
                                EPON
                              </SelectItem>
                            </SelectContent>
                          </Select>
                          <FormMessage className='text-[10px]' />
                        </FormItem>
                      )}
                    />

                    {/* Tipe ODP */}
                    <FormField
                      control={form.control}
                      name='type'
                      render={({ field }) => (
                        <FormItem className='space-y-1'>
                          <FormLabel className='text-xs'>Tipe ODP</FormLabel>
                          <Select
                            onValueChange={field.onChange}
                            value={field.value}
                          >
                            <FormControl>
                              <SelectTrigger className='h-8 text-xs'>
                                <SelectValue placeholder='Pilih tipe' />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                              <SelectItem value='splitter' className='text-xs'>
                                Splitter
                              </SelectItem>
                              <SelectItem value='ratio' className='text-xs'>
                                Ratio
                              </SelectItem>
                            </SelectContent>
                          </Select>
                          <FormMessage className='text-[10px]' />
                        </FormItem>
                      )}
                    />

                    {/* Kapasitas Splitter */}
                    <FormField
                      control={form.control}
                      name='splitter_type'
                      render={({ field }) => (
                        <FormItem className='space-y-1'>
                          <FormLabel className='text-xs'>Kapasitas</FormLabel>
                          <Select
                            onValueChange={field.onChange}
                            value={field.value || '1:8'}
                          >
                            <FormControl>
                              <SelectTrigger className='h-8 text-xs'>
                                <SelectValue placeholder='Pilih kapasitas' />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                              <SelectItem value='1:2' className='text-xs'>
                                1:2
                              </SelectItem>
                              <SelectItem value='1:4' className='text-xs'>
                                1:4
                              </SelectItem>
                              <SelectItem value='1:8' className='text-xs'>
                                1:8
                              </SelectItem>
                              <SelectItem value='1:16' className='text-xs'>
                                1:16
                              </SelectItem>
                              <SelectItem value='1:32' className='text-xs'>
                                1:32
                              </SelectItem>
                            </SelectContent>
                          </Select>
                          <FormMessage className='text-[10px]' />
                        </FormItem>
                      )}
                    />
                  </div>
                ) : (
                  <div className='space-y-3'>
                    <div className='grid grid-cols-2 gap-2'>
                      {/* GPON/EPON */}
                      <FormField
                        control={form.control}
                        name='gpon_type'
                        render={({ field }) => (
                          <FormItem className='space-y-1'>
                            <FormLabel className='text-xs'>GPON/EPON</FormLabel>
                            <Select
                              onValueChange={field.onChange}
                              value={field.value || 'GPON'}
                            >
                              <FormControl>
                                <SelectTrigger className='h-8 text-xs'>
                                  <SelectValue placeholder='GPON/EPON' />
                                </SelectTrigger>
                              </FormControl>
                              <SelectContent>
                                <SelectItem value='GPON' className='text-xs'>
                                  GPON
                                </SelectItem>
                                <SelectItem value='EPON' className='text-xs'>
                                  EPON
                                </SelectItem>
                              </SelectContent>
                            </Select>
                            <FormMessage className='text-[10px]' />
                          </FormItem>
                        )}
                      />

                      {/* Tipe ODP */}
                      <FormField
                        control={form.control}
                        name='type'
                        render={({ field }) => (
                          <FormItem className='space-y-1'>
                            <FormLabel className='text-xs'>Tipe ODP</FormLabel>
                            <Select
                              onValueChange={field.onChange}
                              value={field.value}
                            >
                              <FormControl>
                                <SelectTrigger className='h-8 text-xs'>
                                  <SelectValue placeholder='Pilih tipe' />
                                </SelectTrigger>
                              </FormControl>
                              <SelectContent>
                                <SelectItem value='splitter' className='text-xs'>
                                  Splitter
                                </SelectItem>
                                <SelectItem value='ratio' className='text-xs'>
                                  Ratio
                                </SelectItem>
                              </SelectContent>
                            </Select>
                            <FormMessage className='text-[10px]' />
                          </FormItem>
                        )}
                      />
                    </div>

                    {/* TAP & THRU Ratio */}
                    <div className='grid grid-cols-2 gap-3'>
                      <FormField
                        control={form.control}
                        name='ratio_used'
                        render={({ field }) => (
                          <FormItem className='space-y-1'>
                            <FormLabel className='text-xs'>Digunakan (TAP)</FormLabel>
                            <FormControl>
                              <Input
                                type='number'
                                {...field}
                                value={field.value ?? ''}
                                onChange={(e) => {
                                  const val = e.target.value === '' ? null : parseInt(e.target.value)
                                  field.onChange(val)
                                  if (val !== null && val >= 0 && val <= 100) {
                                    form.setValue('ratio_total', 100 - val)
                                  }
                                }}
                                className='h-8 text-xs'
                              />
                            </FormControl>
                            <FormMessage className='text-[10px]' />
                          </FormItem>
                        )}
                      />
                      <FormField
                        control={form.control}
                        name='ratio_total'
                        render={({ field }) => (
                          <FormItem className='space-y-1'>
                            <FormLabel className='text-xs'>Total (THRU)</FormLabel>
                            <FormControl>
                              <Input
                                type='number'
                                {...field}
                                value={field.value ?? ''}
                                onChange={(e) => {
                                  const val = e.target.value === '' ? null : parseInt(e.target.value)
                                  field.onChange(val)
                                  if (val !== null && val >= 0 && val <= 100) {
                                    form.setValue('ratio_used', 100 - val)
                                  }
                                }}
                                className='h-8 text-xs'
                              />
                            </FormControl>
                            <FormMessage className='text-[10px]' />
                          </FormItem>
                        )}
                      />
                    </div>
                  </div>
                )}



                {/* NOMOR CORE PICKER */}
                <FormField
                  control={form.control}
                  name='core_number'
                  render={({ field }) => (
                    <FormItem className='space-y-1'>
                      <FiberCorePicker
                        value={field.value as number | null}
                        onChange={(val) => field.onChange(val)}
                        onCableColorChange={(colorId) => form.setValue('cable_color_id', colorId)}
                        label="Nomor Core (Uplink/ODC)"
                      />
                      <FormMessage className='text-[10px]' />
                    </FormItem>
                  )}
                />


                {/* REDAMAN SUMBER */}
                <FormField
                  control={form.control}
                  name='rx_power'
                  render={({ field }) => (
                    <FormItem className='space-y-1'>
                      <FormLabel className='text-xs'>
                        Redaman Sumber (dBm)
                      </FormLabel>
                      <FormControl>
                        <Input
                          placeholder='Contoh: -18.5'
                          {...field}
                          value={field.value || ''}
                          className='h-8 text-xs'
                        />
                      </FormControl>
                      <FormMessage className='text-[10px]' />
                    </FormItem>
                  )}
                />



                {/* LOKASI / ALAMAT */}
                <FormField
                  control={form.control}
                  name='location'
                  render={({ field }) => (
                    <FormItem className='space-y-1'>
                      <FormLabel className='text-xs'>Lokasi / Alamat</FormLabel>
                      <FormControl>
                        <Input
                          placeholder='Samping tiang listrik...'
                          {...field}
                          className='h-8 text-xs'
                        />
                      </FormControl>
                      <FormMessage className='text-[10px]' />
                    </FormItem>
                  )}
                />

                {/* LINK GOOGLE MAPS */}
                <FormField
                  control={form.control}
                  name='maps_link'
                  render={({ field }) => (
                    <FormItem className='space-y-1'>
                      <FormLabel className='text-xs'>
                        Link Google Maps
                      </FormLabel>
                      <FormControl>
                        <div className='flex gap-2'>
                          <Input
                            placeholder='https://goo.gl/maps/... atau lat,lng'
                            {...field}
                            value={field.value || ''}
                            className='h-8 text-xs'
                          />
                          <Button
                            type='button'
                            variant='secondary'
                            size='sm'
                            className='h-8 px-3 text-[10px] font-black'
                            onClick={convertCurrentMapsLink}
                          >
                            Convert
                          </Button>
                        </div>
                      </FormControl>
                      <FormMessage className='text-[10px]' />
                    </FormItem>
                  )}
                />

                <div className='flex items-center justify-between border-t pt-2'>
                  <div className='flex flex-col'>
                    <span className='text-[10px] font-black text-muted-foreground uppercase'>
                      Koordinat ODP
                    </span>
                    <span className='text-[8px] text-muted-foreground italic'>
                      Geser marker di peta
                    </span>
                  </div>
                  <div className='flex gap-1'>
                    <Button
                      type='button'
                      variant='outline'
                      size='sm'
                      className='h-8 gap-2 rounded-full text-[10px] font-black'
                      onClick={fillMapsFromCoords}
                    >
                      <Link2 className='h-3 w-3' /> Buat Link
                    </Button>
                    <Button
                      type='button'
                      variant='default'
                      size='sm'
                      className='h-8 gap-2 rounded-full border-none bg-[#1e293b] px-4 text-[10px] font-black text-white shadow-md transition-all hover:bg-[#0f172a]'
                      onClick={() => setIsMapPickerOpen(true)}
                    >
                      <MapPin className='h-3 w-3' /> Buka Peta
                    </Button>
                  </div>
                </div>

                <div className='grid grid-cols-2 gap-3'>
                  <FormField
                    control={form.control}
                    name='lat'
                    render={({ field }) => (
                      <FormItem className='space-y-1'>
                        <FormLabel className='text-xs'>Latitude</FormLabel>
                        <FormControl>
                          <Input
                            type='number'
                            step='any'
                            placeholder='-6.123'
                            {...field}
                            value={field.value ?? ''}
                            onChange={(e) =>
                              field.onChange(
                                e.target.value === ''
                                  ? null
                                  : parseFloat(e.target.value)
                              )
                            }
                            className='h-8 text-xs'
                          />
                        </FormControl>
                        <FormMessage className='text-[10px]' />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={form.control}
                    name='lng'
                    render={({ field }) => (
                      <FormItem className='space-y-1'>
                        <FormLabel className='text-xs'>Longitude</FormLabel>
                        <FormControl>
                          <Input
                            type='number'
                            step='any'
                            placeholder='110.123'
                            {...field}
                            value={field.value ?? ''}
                            onChange={(e) =>
                              field.onChange(
                                e.target.value === ''
                                  ? null
                                  : parseFloat(e.target.value)
                              )
                            }
                            className='h-8 text-xs'
                          />
                        </FormControl>
                        <FormMessage className='text-[10px]' />
                      </FormItem>
                    )}
                  />
                </div>

            </div>
          </div>

          <div className='flex justify-end gap-2 p-4 pt-3 border-t dark:border-slate-800 bg-white dark:bg-slate-900 z-10 shrink-0'>
            <Button
              type='button'
              variant='ghost'
              size='sm'
              onClick={onClose}
              disabled={mutation.isPending}
              className='h-9 text-xs font-bold'
            >
              Batal
            </Button>
            <Button
              type='submit'
              size='sm'
              disabled={mutation.isPending}
              className='h-9 text-xs font-bold bg-amber-600 hover:bg-amber-700 text-white'
            >
              {mutation.isPending ? 'Menyimpan...' : 'Simpan'}
            </Button>
          </div>
        </form>
      </Form>

      <MapPicker
        isOpen={isMapPickerOpen}
        onClose={() => setIsMapPickerOpen(false)}
        initialLat={form.getValues('lat')}
        initialLng={form.getValues('lng')}
        onSelect={(lat, lng) => {
          form.setValue('lat', lat)
          form.setValue('lng', lng)
          form.setValue(
            'maps_link',
            `https://www.google.com/maps?q=${lat},${lng}`
          )
        }}
      />
    </DialogContent>
  </Dialog>
  )
}
