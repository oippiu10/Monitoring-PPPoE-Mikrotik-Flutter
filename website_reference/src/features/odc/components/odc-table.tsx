"use no memo";

import { useState } from 'react'
import {
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  getPaginationRowModel,
  useReactTable,
  type SortingState,
  type ColumnDef,
  type FilterFn,
} from '@tanstack/react-table'
import { DataTablePagination } from '@/components/data-table/pagination'
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
import { ODCMutateDialog } from './odc-mutate-drawer'
import { getFiberColors, inferCableSizeFromCoreNumber } from '@/lib/fiber-color'
import { ODCDetailDialog } from './odc-detail-dialog'
import { DataTableToolbar, DataTableColumnHeader } from '@/components/data-table'
import { Trash2, Pencil, MapPin } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { type ODC } from '../data/schema'
import { usePermission } from '@/lib/permissions'

interface ODCTableProps {
  data: ODC[]
  isLoading?: boolean
}

export function ODCTable({ 
  data, 
  isLoading,
}: ODCTableProps) {
  const queryClient = useQueryClient()
  const permissions = usePermission()
  const [sorting, setSorting] = useState<SortingState>([])
  const [globalFilter, setGlobalFilter] = useState(() => {
    if (typeof window !== 'undefined') {
      const params = new URLSearchParams(window.location.search)
      return params.get('search') || ''
    }
    return ''
  })
  
  // State for mutation dialogs
  const [isMutateOpen, setIsMutateOpen] = useState(false)
  const [editingODC, setEditingODC] = useState<ODC | null>(null)
  const [isDeleteOpen, setIsDeleteOpen] = useState(false)
  const [odcToDelete, setODCToDelete] = useState<ODC | null>(null)
  
  // State for detail dialog
  const [isDetailOpen, setIsDetailOpen] = useState(false)
  const [selectedODC, setSelectedODC] = useState<ODC | null>(null)

  // Fuzzy filter: normalize spasi & huruf besar supaya 'ODC1' cocok dengan 'ODC 1'
  const fuzzyFilter: FilterFn<ODC> = (row, _columnId, filterValue: string) => {
    const normalize = (s: string) => s.toLowerCase().replace(/\s+/g, '')
    const query = normalize(filterValue)
    const fields = [
      row.original.name,
      row.original.location,
      row.original.cable_color_name,
    ]
    return fields.some(f => f && normalize(String(f)).includes(query))
  }

  const deleteMutation = useMutation({
    mutationFn: async (id: number) => {
      const res = await api.delete(`/odc.php?id=${id}`)
      return res.data
    },
    onSuccess: (data) => {
      if (data.success) {
        toast.success('ODC berhasil dihapus')
        queryClient.invalidateQueries({ queryKey: ['odcs'] })
        setIsDeleteOpen(false)
      } else {
        toast.error(data.message || 'Gagal menghapus ODC')
      }
    },
    onError: (error: any) => {
      toast.error(error.response?.data?.message || 'Terjadi kesalahan sistem')
    }
  })

  const columns: ColumnDef<ODC>[] = [
    {
      accessorKey: 'name',
      header: ({ column }) => <DataTableColumnHeader column={column} title='Nama ODC' />,
      cell: ({ row }) => <span className='font-bold text-amber-600 dark:text-amber-400'>{row.original.name}</span>,
    },
    {
      accessorKey: 'capacity',
      header: ({ column }) => <DataTableColumnHeader column={column} title='Kapasitas (Port)' />,
      cell: ({ row }) => <span className='font-semibold'>{row.original.capacity} Port</span>,
    },
    {
      accessorKey: 'core_number',
      header: 'Ukuran/Tube',
      cell: ({ row }) => {
        const coreNum = row.original.core_number
        if (coreNum !== null && coreNum !== undefined) {
          const fiberInfo = getFiberColors(coreNum)
          const cableSize = inferCableSizeFromCoreNumber(coreNum)
          if (fiberInfo) {
            return (
              <div className='flex flex-col gap-0.5 text-xs'>
                <span className='text-[10.5px] font-bold text-slate-700 dark:text-slate-300'>
                  {cableSize} Core
                </span>
                <span className='text-[10px] text-muted-foreground flex items-center gap-1'>
                  Tube: 
                  <span 
                    className='h-2 w-2 rounded-full border border-black/10 shrink-0 inline-block' 
                    style={{ backgroundColor: fiberInfo.tube.code }} 
                  /> 
                  {fiberInfo.tube.name}
                </span>
              </div>
            )
          }
        }
        return <span className='text-xs text-muted-foreground'>-</span>
      }
    },
    {
      accessorKey: 'cable_color_name',
      header: ({ column }) => <DataTableColumnHeader column={column} title='Warna Kabel' />,
      cell: ({ row }) => {
        const { cable_color_name, cable_color_code } = row.original
        if (cable_color_name && cable_color_code) {
          return (
            <div className='flex items-center gap-1.5'>
              <div 
                className='h-3 w-3 rounded-full border border-black/10 shrink-0'
                style={{ backgroundColor: cable_color_code }}
              />
              <span className='text-xs font-semibold'>{cable_color_name}</span>
            </div>
          )
        }
        return <span className='text-xs text-muted-foreground'>-</span>
      }
    },
    {
      accessorKey: 'location',
      header: ({ column }) => <DataTableColumnHeader column={column} title='Alamat' />,
    },
    {
      accessorKey: 'coordinates',
      header: 'Koordinat',
      cell: ({ row }) => {
        const { lat, lng, maps_link } = row.original
        if (lat && lng) {
          return (
            <a
              href={maps_link || `https://www.google.com/maps?q=${lat},${lng}`}
              target='_blank'
              rel='noopener noreferrer'
              className='flex items-center gap-1 text-xs text-blue-500 hover:underline'
              onClick={e => e.stopPropagation()}
            >
              <MapPin className='h-3 w-3' />
              {Number(lat).toFixed(6)}, {Number(lng).toFixed(6)}
            </a>
          )
        }
        return <span className='text-muted-foreground'>-</span>
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
                className='h-7 w-7 text-blue-600 hover:text-blue-700 hover:bg-blue-50'
                onClick={() => {
                  setEditingODC(row.original)
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
                className='h-7 w-7 text-red-600 hover:text-red-700 hover:bg-red-50'
                onClick={() => {
                  setODCToDelete(row.original)
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
    filterFns: {
      fuzzy: fuzzyFilter,
    },
    globalFilterFn: fuzzyFilter,
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
  })

  return (
    <div className='flex flex-1 flex-col gap-4'>
      <DataTableToolbar 
        table={table}
        searchPlaceholder='Cari ODC...'
      />
      <div className='overflow-hidden rounded-md border'>
        <Table>
          <TableHeader>
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <TableHead key={header.id}>
                    {header.isPlaceholder
                      ? null
                      : flexRender(
                          header.column.columnDef.header,
                          header.getContext()
                        )}
                  </TableHead>
                ))}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {isLoading ? (
              <TableRow>
                <TableCell colSpan={columns.length} className='h-24 text-center'>
                  Loading...
                </TableCell>
              </TableRow>
            ) : table.getRowModel().rows?.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow 
                  key={row.id} 
                  className="cursor-pointer"
                  onClick={() => {
                    setSelectedODC(row.original)
                    setIsDetailOpen(true)
                  }}
                >
                  {row.getVisibleCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {flexRender(
                        cell.column.columnDef.cell,
                        cell.getContext()
                      )}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={columns.length} className='h-24 text-center'>
                  Tidak ada data ODC.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <DataTablePagination table={table} />

      <ODCMutateDialog 
        isOpen={isMutateOpen}
        onClose={() => {
          setIsMutateOpen(false)
          setEditingODC(null)
        }}
        odc={editingODC}
      />

      <ODCDetailDialog 
        isOpen={isDetailOpen}
        onClose={() => {
          setIsDetailOpen(false)
          setSelectedODC(null)
        }}
        odc={selectedODC}
        onEdit={(odc) => {
          if (!permissions.canManageCustomers) return
          setEditingODC(odc)
          setIsMutateOpen(true)
        }}
        onDelete={(odc) => {
          setODCToDelete(odc)
          setIsDeleteOpen(true)
        }}
      />

      <ConfirmDialog 
        open={isDeleteOpen}
        onOpenChange={setIsDeleteOpen}
        title="Hapus ODC"
        desc={`Apakah Anda yakin ingin menghapus ODC "${odcToDelete?.name}"? Data ini akan dihapus permanen.`}
        confirmText="Hapus"
        destructive
        isLoading={deleteMutation.isPending}
        handleConfirm={() => {
          if (odcToDelete?.id) deleteMutation.mutate(odcToDelete.id)
        }}
      />
    </div>
  )
}
