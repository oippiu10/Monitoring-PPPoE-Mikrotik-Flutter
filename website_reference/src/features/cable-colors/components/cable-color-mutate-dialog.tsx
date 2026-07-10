import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { api } from '@/lib/api'
import { useRouterStore } from '@/stores/router-store'
import { cableColorSchema, type CableColor } from '../data/schema'

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
import { cn } from '@/lib/utils'

interface Props {
  isOpen: boolean
  onClose: () => void
  cableColor?: CableColor | null
}

const PRESET_COLORS = [
  '#3b82f6', // Blue
  '#10b981', // Green
  '#f59e0b', // Yellow
  '#ef4444', // Red
  '#8b5cf6', // Purple
  '#ec4899', // Pink
  '#f97316', // Orange
  '#06b6d4', // Cyan
  '#14b8a6', // Teal
  '#6366f1', // Indigo
  '#a855f7', // Purple-light
  '#64748b', // Slate
]

export function CableColorMutateDialog({ isOpen, onClose, cableColor }: Props) {
  const isEditing = !!cableColor
  const { activeRouter } = useRouterStore()
  const queryClient = useQueryClient()

  const form = useForm<CableColor>({
    resolver: zodResolver(cableColorSchema),
    defaultValues: {
      name: '',
      color_code: '#3b82f6',
    },
  })

  useEffect(() => {
    if (isOpen) {
      if (cableColor) {
        form.reset({
          ...cableColor,
        })
      } else {
        form.reset({
          name: '',
          color_code: '#3b82f6',
        })
      }
    }
  }, [isOpen, cableColor, form])

  const mutation = useMutation({
    mutationFn: async (data: CableColor) => {
      const payload = {
        ...data,
        router_id: activeRouter?.id,
      }
      if (isEditing && cableColor) {
        return api.put('/cable_colors.php', { ...payload, id: cableColor.id })
      }
      return api.post('/cable_colors.php', payload)
    },
    onSuccess: () => {
      toast.success(isEditing ? 'Warna kabel berhasil diperbarui' : 'Warna kabel berhasil ditambahkan')
      queryClient.invalidateQueries({ queryKey: ['cable-colors'] })
      onClose()
    },
    onError: (err: any) => {
      toast.error(err.response?.data?.message || 'Gagal menyimpan warna kabel')
    },
  })

  const onSubmit = (data: CableColor) => {
    mutation.mutate(data)
  }

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className='sm:max-w-[420px] p-0 overflow-hidden border-none rounded-3xl shadow-2xl bg-white dark:bg-slate-900'>
        <DialogHeader className='px-6 pt-6 pb-4 bg-linear-to-r from-blue-500/10 to-transparent'>
          <DialogTitle className='text-lg font-black uppercase tracking-wider text-blue-600 dark:text-blue-400'>
            {isEditing ? 'Edit Warna Kabel' : 'Tambah Warna Kabel'}
          </DialogTitle>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className='space-y-5 px-6 pb-6'>
            <FormField
              control={form.control}
              name='name'
              render={({ field }) => (
                <FormItem className="space-y-1.5">
                  <FormLabel className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Nama Warna Kabel</FormLabel>
                  <FormControl>
                    <Input placeholder='Contoh: Core Utama Biru' {...field} className="h-9 text-xs font-semibold" />
                  </FormControl>
                  <FormMessage className="text-[10px]" />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name='color_code'
              render={({ field }) => (
                <FormItem className="space-y-2">
                  <FormLabel className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Pilih Warna</FormLabel>
                  <div className='flex gap-3 items-center'>
                    <FormControl>
                      <Input 
                        type='color' 
                        {...field} 
                        className="h-10 w-12 p-0.5 border cursor-pointer rounded-lg shrink-0" 
                      />
                    </FormControl>
                    <Input 
                      placeholder='#ffffff' 
                      {...field} 
                      onChange={(e) => field.onChange(e.target.value)}
                      className="h-9 text-xs font-mono font-semibold" 
                    />
                  </div>
                  
                  {/* Preset Colors Grid */}
                  <div className='grid grid-cols-6 gap-2 pt-1'>
                    {PRESET_COLORS.map((color) => (
                      <button
                        key={color}
                        type='button'
                        onClick={() => field.onChange(color)}
                        className={cn(
                          'h-8 w-full rounded-md border border-black/10 dark:border-white/10 transition-all transform hover:scale-110 active:scale-95',
                          field.value === color ? 'ring-2 ring-primary ring-offset-2 dark:ring-offset-slate-900 scale-105' : ''
                        )}
                        style={{ backgroundColor: color }}
                        title={color}
                      />
                    ))}
                  </div>
                  <FormMessage className="text-[10px]" />
                </FormItem>
              )}
            />

            <div className='flex justify-end gap-2 pt-3 border-t dark:border-slate-800'>
              <Button type='button' variant='ghost' size='sm' onClick={onClose} className="h-9 text-xs font-bold">
                Batal
              </Button>
              <Button type='submit' size='sm' disabled={mutation.isPending} className="h-9 text-xs font-bold bg-blue-600 hover:bg-blue-700 text-white">
                {mutation.isPending ? 'Menyimpan...' : 'Simpan'}
              </Button>
            </div>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}
