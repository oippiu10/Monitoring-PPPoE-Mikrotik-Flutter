import { type ColumnDef } from '@tanstack/react-table'
import { Badge } from '@/components/ui/badge'
import { DataTableColumnHeader } from '@/components/data-table'
import { type ODP } from '../data/schema'
import { getFiberColors, inferCableSizeFromCoreNumber } from '@/lib/fiber-color'
import { MapPin, MoreHorizontal, Pencil, Trash2, Users } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

export const columns: ColumnDef<ODP>[] = [
  {
    id: 'rowNumber',
    header: 'No.',
    cell: ({ row }) => <span className='text-xs text-muted-foreground'>{row.index + 1}</span>,
  },
  {
    accessorKey: 'name',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='Nama ODP' />
    ),
    cell: ({ row }) => <div className='font-bold'>{row.getValue('name')}</div>,
  },
  {
    accessorKey: 'odc_name',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='ODC Induk / Hulu' />
    ),
    cell: ({ row }) => {
      const odcName = row.original.odc_name
      if (odcName) {
        return (
          <Badge variant='outline' className='bg-amber-50 dark:bg-amber-950/20 text-amber-600 dark:text-amber-400 border-amber-200 dark:border-amber-900/50 font-bold'>
            {odcName}
          </Badge>
        )
      }
      const parentId = row.original.parent_id
      const parentName = row.original.parent_odp_name
      if (parentId) {
        return (
          <Badge variant='outline' className='bg-blue-50 dark:bg-blue-950/20 text-blue-600 dark:text-blue-400 border-blue-200 dark:border-blue-900/50 font-bold'>
            {parentName || 'Sumber Terusan (ODP)'}
          </Badge>
        )
      }
      return <span className='text-xs text-muted-foreground'>Direct Router</span>
    }
  },
  {
    accessorKey: 'type',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='Tipe' />
    ),
    cell: ({ row }) => {
      const type = row.getValue('type') as string
      return (
        <Badge variant={type === 'splitter' ? 'default' : 'secondary'} className='capitalize'>
          {type}
        </Badge>
      )
    },
  },
  {
    accessorKey: 'splitter_type',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='Kapasitas' />
    ),
    cell: ({ row }) => {
        const type = row.original.type
        if (type === 'splitter') return row.getValue('splitter_type') || '-'
        return `${row.original.ratio_used}/${row.original.ratio_total}`
    },
  },
  {
    accessorKey: 'core_number',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='Ukuran/Tube' />
    ),
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
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='Warna Kabel' />
    ),
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
    accessorKey: 'total_users',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='Terpakai' />
    ),
    cell: ({ row }) => {
        const count = row.getValue('total_users') as number
        return (
            <div className='flex items-center gap-1.5'>
                <Users className='h-3.5 w-3.5 text-muted-foreground' />
                <span className='font-medium'>{count} User</span>
            </div>
        )
    }
  },
  {
    accessorKey: 'location',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title='Lokasi' />
    ),
    cell: ({ row }) => {
        const loc = row.getValue('location') as string
        const maps = row.original.maps_link
        return (
            <div className='flex items-center gap-2 max-w-48'>
                <MapPin className='h-3.5 w-3.5 shrink-0 text-muted-foreground' />
                <span className='text-xs truncate'>{loc}</span>
                {maps && (
                    <a 
                        href={maps} 
                        target='_blank' 
                        rel='noreferrer' 
                        className='text-primary hover:underline ml-auto shrink-0'
                        onClick={(e) => e.stopPropagation()}
                    >
                        Maps
                    </a>
                )}
            </div>
        )
    },
  },
  {
    id: 'actions',
    cell: ({ row, table }) => {
      const odp = row.original
      const { onEdit, onDelete, canEdit, canDelete } = table.options.meta as any
      if (!canEdit && !canDelete) return null
      
      return (
        <div className="flex justify-end">
            <DropdownMenu>
            <DropdownMenuTrigger asChild onClick={(e) => e.stopPropagation()}>
                <Button variant='ghost' className='h-8 w-8 p-0'>
                <span className='sr-only'>Buka menu</span>
                <MoreHorizontal className='h-4 w-4' />
                </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align='end'>
                <DropdownMenuLabel>Aksi</DropdownMenuLabel>
                <DropdownMenuSeparator />
                {canEdit && (
                  <DropdownMenuItem onClick={() => onEdit?.(odp)}>
                      <Pencil className='mr-2 h-4 w-4' /> Edit ODP
                  </DropdownMenuItem>
                )}
                {canDelete && (
                  <DropdownMenuItem 
                      onClick={() => onDelete?.(odp)}
                      className='text-destructive focus:text-destructive'
                  >
                      <Trash2 className='mr-2 h-4 w-4' /> Hapus ODP
                  </DropdownMenuItem>
                )}
            </DropdownMenuContent>
            </DropdownMenu>
        </div>
      )
    },
  },
]
