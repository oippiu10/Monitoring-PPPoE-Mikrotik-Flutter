"use no memo";

import { useState } from 'react'
import {
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  useReactTable,
  type SortingState,
  type ColumnDef,
} from '@tanstack/react-table'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { toast } from 'sonner'
import { ConfirmDialog } from '@/components/confirm-dialog'
import { CableColorMutateDialog } from './cable-color-mutate-dialog'
import { DataTableToolbar } from '@/components/data-table'
import { Trash2, Pencil } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { type CableColor } from '../data/schema'
import { usePermission } from '@/lib/permissions'

interface CableColorTableProps {
  data: CableColor[]
  isLoading?: boolean
}

export function CableColorTable({ 
  data, 
  isLoading,
}: CableColorTableProps) {
  const queryClient = useQueryClient()
  const permissions = usePermission()
  const [sorting, setSorting] = useState<SortingState>([])
  const [globalFilter, setGlobalFilter] = useState('')
  
  // State for mutation dialogs
  const [isMutateOpen, setIsMutateOpen] = useState(false)
  const [editingColor, setEditingColor] = useState<CableColor | null>(null)
  const [isDeleteOpen, setIsDeleteOpen] = useState(false)
  const [colorToDelete, setColorToDelete] = useState<CableColor | null>(null)

  const deleteMutation = useMutation({
    mutationFn: async (id: number) => {
      const res = await api.delete(`/cable_colors.php?id=${id}`)
      return res.data
    },
    onSuccess: (res) => {
      if (res.success) {
        toast.success('Warna kabel berhasil dihapus')
        queryClient.invalidateQueries({ queryKey: ['cable-colors'] })
        setIsDeleteOpen(false)
      } else {
        toast.error(res.message || 'Gagal menghapus warna kabel')
      }
    },
    onError: (error: any) => {
      toast.error(error.response?.data?.message || 'Terjadi kesalahan sistem')
    }
  })

  const columns: ColumnDef<CableColor>[] = [
    {
      id: 'rowNumber',
      header: 'No.',
      cell: ({ row }) => <span className='text-xs text-muted-foreground'>{row.index + 1}</span>,
    },
    {
      accessorKey: 'name',
      header: 'Nama Warna Kabel',
      cell: ({ row }) => <span className='font-bold text-slate-800 dark:text-slate-200'>{row.original.name}</span>,
    },
    {
      accessorKey: 'color_code',
      header: 'Warna Visual',
      cell: ({ row }) => {
        const color = row.original.color_code
        return (
          <div className='flex items-center gap-2'>
            <div 
              className='h-5 w-5 rounded-full border border-black/10 dark:border-white/10 shrink-0 shadow-sm'
              style={{ backgroundColor: color }}
            />
            <span className='font-mono text-xs uppercase text-muted-foreground'>{color}</span>
          </div>
        )
      },
    },
    {
      id: 'actions',
      header: 'Aksi',
      cell: ({ row }) => {
        return (
          <div className='flex gap-1' onClick={e => e.stopPropagation()}>
            {permissions.canManageCustomers && (
              <Button
                variant='ghost'
                size='icon'
                className='h-7 w-7 text-blue-600 hover:text-blue-700 hover:bg-blue-50 dark:hover:bg-blue-950/20'
                onClick={() => {
                  setEditingColor(row.original)
                  setIsMutateOpen(true)
                }}
              >
                <Pencil className='h-3.5 w-3.5' />
              </Button>
            )}
            {permissions.canDeleteCustomers && (
              <Button
                variant='ghost'
                size='icon'
                className='h-7 w-7 text-red-600 hover:text-red-700 hover:bg-red-50 dark:hover:bg-red-950/20'
                onClick={() => {
                  setColorToDelete(row.original)
                  setIsDeleteOpen(true)
                }}
              >
                <Trash2 className='h-3.5 w-3.5' />
              </Button>
            )}
          </div>
        )
      },
    },
  ]

  // eslint-disable-next-line react-hooks/incompatible-library
  const table = useReactTable({
    data,
    columns,
    state: {
      sorting,
      globalFilter,
    },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
  })

  return (
    <div className='flex flex-1 flex-col gap-4'>
      <div className='flex items-center justify-between gap-4'>
        <DataTableToolbar 
          table={table}
          searchPlaceholder='Cari Warna Kabel...'
        />
        {permissions.canManageCustomers && (
          <Button 
            size='sm' 
            onClick={() => {
              setEditingColor(null)
              setIsMutateOpen(true)
            }}
            className='bg-blue-600 hover:bg-blue-700 text-white font-bold h-9'
          >
            + Tambah Warna Kabel
          </Button>
        )}
      </div>

      <div className='grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4'>
        {isLoading ? (
          Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className='h-36 rounded-2xl bg-muted animate-pulse border shadow-sm' />
          ))
        ) : table.getRowModel().rows?.length ? (
          table.getRowModel().rows.map((row) => {
            const color = row.original
            return (
              <div 
                key={color.id}
                className='group relative flex flex-col items-center justify-center gap-3 overflow-hidden rounded-2xl border bg-card p-6 shadow-sm transition-all hover:border-primary/40 hover:shadow-md cursor-pointer'
                onClick={() => {
                  if (permissions.canManageCustomers) {
                    setEditingColor(color)
                    setIsMutateOpen(true)
                  }
                }}
              >
                {/* Background glow effect based on color */}
                <div 
                    className="absolute inset-0 opacity-[0.03] dark:opacity-[0.08] transition-opacity group-hover:opacity-[0.08] dark:group-hover:opacity-[0.15]"
                    style={{ backgroundColor: color.color_code }}
                />

                <div 
                  className='relative h-14 w-14 shrink-0 rounded-full border-2 border-background shadow-[0_0_10px_rgba(0,0,0,0.1)] transition-transform duration-300 group-hover:scale-110 ring-4 ring-muted/50'
                  style={{ backgroundColor: color.color_code }}
                />
                <div className='text-center z-10'>
                  <h3 className='text-sm font-black uppercase tracking-wider text-slate-800 dark:text-slate-200 line-clamp-1'>
                    {color.name}
                  </h3>
                  <p className='mt-0.5 font-mono text-[10px] uppercase tracking-widest text-muted-foreground'>
                    {color.color_code}
                  </p>
                </div>

                <div className='absolute top-2 right-2 flex gap-1 opacity-0 transition-opacity duration-200 group-hover:opacity-100' onClick={(e) => e.stopPropagation()}>
                  {permissions.canManageCustomers && (
                    <Button
                      variant='ghost'
                      size='icon'
                      className='h-7 w-7 rounded-full text-blue-600 hover:bg-blue-100 hover:text-blue-700 dark:text-blue-400 dark:hover:bg-blue-900/40'
                      onClick={() => {
                        setEditingColor(color)
                        setIsMutateOpen(true)
                      }}
                    >
                      <Pencil className='h-3.5 w-3.5' />
                    </Button>
                  )}
                  {permissions.canDeleteCustomers && (
                    <Button
                      variant='ghost'
                      size='icon'
                      className='h-7 w-7 rounded-full text-red-600 hover:bg-red-100 hover:text-red-700 dark:text-red-400 dark:hover:bg-red-900/40'
                      onClick={() => {
                        setColorToDelete(color)
                        setIsDeleteOpen(true)
                      }}
                    >
                      <Trash2 className='h-3.5 w-3.5' />
                    </Button>
                  )}
                </div>
              </div>
            )
          })
        ) : (
          <div className='col-span-full py-12 text-center border-2 border-dashed rounded-2xl bg-muted/30'>
            <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-muted mb-4">
              <Pencil className="h-6 w-6 text-muted-foreground opacity-50" />
            </div>
            <h3 className="text-sm font-bold text-slate-800 dark:text-slate-200">Tidak ada warna kabel</h3>
            <p className="text-xs text-muted-foreground mt-1 mb-4">Silakan tambahkan warna baru untuk dokumentasi</p>
            {permissions.canManageCustomers && (
              <Button 
                size='sm' 
                onClick={() => {
                  setEditingColor(null)
                  setIsMutateOpen(true)
                }}
                className='bg-blue-600 hover:bg-blue-700 text-white font-bold h-9'
              >
                + Tambah Warna Kabel Pertama
              </Button>
            )}
          </div>
        )}
      </div>

      <CableColorMutateDialog 
        isOpen={isMutateOpen}
        onClose={() => {
          setIsMutateOpen(false)
          setEditingColor(null)
        }}
        cableColor={editingColor}
      />

      <ConfirmDialog 
        open={isDeleteOpen}
        onOpenChange={setIsDeleteOpen}
        title="Hapus Warna Kabel"
        desc={`Apakah Anda yakin ingin menghapus warna kabel "${colorToDelete?.name}"? ODC dan ODP yang menggunakan warna ini akan direset menjadi Tanpa Warna.`}
        confirmText="Hapus"
        destructive
        isLoading={deleteMutation.isPending}
        handleConfirm={() => {
          if (colorToDelete?.id) deleteMutation.mutate(colorToDelete.id)
        }}
      />
    </div>
  )
}
