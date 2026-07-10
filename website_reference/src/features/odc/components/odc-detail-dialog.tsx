"use no memo";

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { type ODC } from '../data/schema'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { getFiberColors } from '@/lib/fiber-color'
import { MapPin, Server, X } from 'lucide-react'
import { toast } from 'sonner'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ScrollArea } from '@/components/ui/scroll-area'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { useMemo, useState } from 'react'
import { cn } from '@/lib/utils'

interface Props {
  isOpen: boolean
  onClose: () => void
  odc: ODC | null
  onEdit?: (odc: ODC) => void
  onDelete?: (odc: ODC) => void
}

export function ODCDetailDialog({ isOpen, onClose, odc, onEdit, onDelete }: Props) {
  const queryClient = useQueryClient()
  const [selectedPortToConnect, setSelectedPortToConnect] = useState<number | null>(null)
  const [selectedOdpIdToConnect, setSelectedOdpIdToConnect] = useState<string>('')

  // Fetch ODP list for the active router to calculate connected ODPs
  const { data: odpList, isLoading: isOdpLoading } = useQuery({
    queryKey: ['odps', odc?.router_id],
    queryFn: async () => {
      if (!odc?.router_id) return []
      const res = await api.get(`/odp.php?router_id=${odc.router_id}`)
      return res.data.data || []
    },
    enabled: isOpen && !!odc,
  })

  // Filter available ODPs (not connected to any hulu yet)
  const availableOdps = useMemo(() => {
    if (!odpList) return []
    return odpList.filter((o: any) => !o.odc_id && !o.parent_id)
  }, [odpList])

  const handleUnlinkOdp = async (odpId: number) => {
    try {
      await api.post('/bulk_update_odp.php', {
        ids: [odpId],
        updates: {
          odc_id: null,
          core_number: null
        }
      })
      toast.success('Hubungan ODP berhasil diputuskan!')
      queryClient.invalidateQueries({ queryKey: ['odps', odc?.router_id] })
    } catch (err: any) {
      toast.error('Gagal memutuskan hubungan ODP: ' + (err.response?.data?.error || err.message))
    }
  }

  // Filter connected ODPs
  const connectedOdps = useMemo(() => {
    if (!odpList || !odc) return []
    return odpList.filter((o: any) => o.odc_id === odc.id)
  }, [odpList, odc])

  const fiberInfo = useMemo(() => getFiberColors(odc?.core_number), [odc?.core_number])

  const capacity = odc?.capacity || 12

  const ports = useMemo(() => {
    const list = []
    for (let i = 1; i <= capacity; i++) {
      const connectedOdp = connectedOdps.find((o: any) => o.core_number === i)
      list.push({
        portNum: i,
        odp: connectedOdp || null
      })
    }
    return list
  }, [capacity, connectedOdps])

  const unallocatedOdps = useMemo(() => {
    return connectedOdps.filter(
      (o: any) =>
        o.core_number === null ||
        o.core_number === undefined ||
        o.core_number < 1 ||
        o.core_number > capacity
    )
  }, [connectedOdps, capacity])

  if (!odc) return null

  return (
    <Dialog open={isOpen} onOpenChange={(v) => !v && onClose()}>
      <DialogContent className="max-w-sm gap-0 p-0 overflow-hidden">
        <DialogHeader className="p-4 border-b">
          <DialogTitle className="flex items-center gap-2 text-base font-semibold">
            <Server className="w-4 h-4 text-blue-600" />
            Detail ODC
          </DialogTitle>
        </DialogHeader>

        <ScrollArea className="max-h-[70vh]">
          <div className="p-4 space-y-4">
            {/* Header identity */}
            <div className="flex items-center justify-between pb-2 border-b">
              <div>
                <p className="text-xs text-muted-foreground">Nama ODC</p>
                <p className="text-lg font-bold leading-tight">{odc.name}</p>
              </div>
              <div className="text-right">
                <p className="text-xs text-muted-foreground">Kapasitas</p>
                <Badge variant="outline" className="text-[10px] h-5 font-bold">
                  {odc.capacity || 12} Port
                </Badge>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              {/* Specs Info */}
              <div className="space-y-2 p-3 bg-muted/30 rounded-lg border border-border/50 col-span-2">
                {odc.core_number !== null && odc.core_number !== undefined && fiberInfo && (
                  <>
                    <div className="flex justify-between items-center text-xs border-t pt-1">
                      <span className="text-muted-foreground">Warna Tube</span>
                      <div className="flex items-center gap-1.5 font-bold text-slate-755">
                        <div 
                          className="h-2.5 w-2.5 rounded-full border border-black/10 shrink-0" 
                          style={{ backgroundColor: fiberInfo.tube.code }} 
                        />
                        <span>{fiberInfo.tube.name}</span>
                      </div>
                    </div>
                    <div className="flex justify-between items-center text-xs border-t pt-1">
                      <span className="text-muted-foreground">Warna Core</span>
                      <div className="flex items-center gap-1.5 font-bold text-slate-755">
                        <div 
                          className="h-2.5 w-2.5 rounded-full border border-black/10 shrink-0" 
                          style={{ backgroundColor: fiberInfo.core.code }} 
                        />
                        <span>{fiberInfo.core.name}</span>
                      </div>
                    </div>
                  </>
                )}
                <div className={`flex justify-between items-center text-xs border-t pt-1`}>
                  <span className="text-muted-foreground">Terhubung</span>
                  <span className="font-bold text-blue-600">{connectedOdps.length} ODP</span>
                </div>
              </div>
            </div>

            {/* Visual Port Grid */}
            <div className="space-y-2">
              <p className="text-[10px] text-muted-foreground font-bold uppercase px-1">Visual Port Grid</p>
              {isOdpLoading ? (
                <p className="text-xs text-muted-foreground italic px-1">Memuat data...</p>
              ) : (
                <div className="grid grid-cols-4 gap-2">
                  {ports.map((port) => {
                    const hasOdp = !!port.odp
                    const rx = port.odp?.rx_power
                    const isCritical = rx !== null && rx !== undefined && rx !== '-' && parseFloat(rx) < -25

                    return (
                      <div 
                        key={port.portNum}
                        className={cn(
                          "flex flex-col justify-between p-2 rounded-xl border text-center transition-all h-16 relative overflow-hidden select-none",
                          hasOdp 
                            ? isCritical
                              ? "bg-rose-50 border-rose-200 text-rose-800 dark:bg-rose-950/20 dark:border-rose-900/50 dark:text-rose-300"
                              : "bg-blue-50 border-blue-200 text-blue-800 dark:bg-blue-950/20 dark:border-blue-900/50 dark:text-blue-300"
                            : "bg-emerald-50/50 border-dashed border-emerald-200 text-emerald-700 dark:bg-emerald-950/10 dark:border-emerald-900/30 dark:text-emerald-400 cursor-pointer hover:bg-emerald-50 dark:hover:bg-emerald-950/20 hover:scale-105 active:scale-95"
                        )}
                        onClick={() => {
                          if (!hasOdp) {
                            setSelectedPortToConnect(port.portNum);
                          }
                        }}
                      >
                        {hasOdp && (
                          <button
                            type="button"
                            className="absolute top-1 right-1 text-rose-500 hover:text-rose-700 p-0.5 rounded-full hover:bg-rose-100 dark:hover:bg-rose-950/40 transition-colors z-10"
                            onClick={(e) => {
                              e.stopPropagation();
                              if (confirm(`Apakah Anda yakin ingin memutuskan hubungan ODP ${port.odp.name} dari ODC ini?`)) {
                                handleUnlinkOdp(port.odp.id);
                              }
                            }}
                          >
                            <X className="w-2.5 h-2.5 stroke-[3]" />
                          </button>
                        )}
                        <span className={cn(
                          "absolute top-1 left-1 text-[8px] font-black w-3.5 h-3.5 rounded-full flex items-center justify-center border",
                          hasOdp
                            ? isCritical 
                              ? "bg-rose-200 border-rose-300 text-rose-850 dark:bg-rose-900 dark:border-rose-800 dark:text-rose-200"
                              : "bg-blue-200 border-blue-300 text-blue-850 dark:bg-blue-900 dark:border-blue-800 dark:text-blue-200"
                            : "bg-emerald-100 border-emerald-200 text-emerald-800 dark:bg-emerald-900 dark:border-emerald-800 dark:text-emerald-200"
                        )}>
                          {port.portNum}
                        </span>
                        
                        <div className="mt-3.5 flex-1 flex flex-col justify-center">
                          {hasOdp ? (
                            <>
                              <span className="text-[9px] font-bold truncate max-w-full px-0.5" title={port.odp.name}>
                                {port.odp.name}
                              </span>
                              <span className="text-[8px] font-mono font-medium opacity-90">
                                {rx && rx !== '-' ? `Rx: ${rx} dBm` : 'Rx: -'}
                              </span>
                            </>
                          ) : (
                            <span className="text-[8px] tracking-wider font-black uppercase text-emerald-600/70 dark:text-emerald-400/50">
                              KOSONG
                            </span>
                          )}
                        </div>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>

            {/* ODP Belum Teralokasi Port */}
            {unallocatedOdps.length > 0 && (
              <div className="space-y-2">
                <p className="text-[10px] text-amber-600 font-bold uppercase px-1">ODP Belum Teralokasi Port ({unallocatedOdps.length})</p>
                <div className="bg-amber-50/30 border border-dashed border-amber-200 rounded-lg p-2.5 space-y-1.5 max-h-36 overflow-y-auto">
                  {unallocatedOdps.map((odp: any) => (
                    <div 
                      key={odp.id} 
                      className="flex justify-between items-center text-xs font-semibold text-amber-900 bg-white border border-amber-100/70 rounded-md px-2.5 py-1.5 shadow-sm"
                    >
                      <span>{odp.name}</span>
                      <span className="text-[10px] text-amber-600 font-mono">
                        {odp.rx_power && odp.rx_power !== '-' ? `Rx: ${odp.rx_power} dBm` : 'Rx: -'}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Notes Section */}
            {odc.notes && (
              <div className="space-y-2">
                <p className="text-[10px] text-muted-foreground font-bold uppercase px-1">Catatan</p>
                <div className="p-3 bg-amber-500/5 rounded-lg border border-amber-500/10">
                  <p className="text-xs text-amber-800 leading-relaxed font-medium">
                    {odc.notes}
                  </p>
                </div>
              </div>
            )}

            {/* Location Section */}
            <div className="space-y-2">
              <p className="text-[10px] text-muted-foreground font-bold uppercase px-1">Lokasi & Alamat</p>
              <div className="p-3 bg-muted/30 rounded-lg border border-border/50 space-y-3">
                <p className="text-xs font-semibold leading-relaxed text-slate-700">
                  {odc.location || 'Tidak ada keterangan alamat'}
                </p>
                
                {odc.maps_link && (
                  <Button 
                    variant="outline" 
                    size="sm" 
                    className="w-full h-8 text-[10px] gap-2 bg-white hover:bg-blue-50 hover:text-blue-600 hover:border-blue-200 transition-colors"
                    onClick={() => window.open(odc.maps_link!, '_blank')}
                  >
                    <MapPin className="w-3 h-3 text-red-500" />
                    Buka di Google Maps
                  </Button>
                )}
              </div>
            </div>
          </div>
        </ScrollArea>
        <div className="flex justify-between items-center p-3 border-t bg-muted/20">
          <Button 
            variant="ghost" 
            size="sm" 
            className="h-8 text-xs text-destructive hover:text-destructive hover:bg-destructive/10"
            onClick={() => {
              if (odc && onDelete) {
                onClose()
                onDelete(odc)
              }
            }}
          >
            Hapus ODC
          </Button>
          <div className="flex gap-2">
            <Button variant="ghost" size="sm" onClick={onClose} className="h-8 text-xs">Tutup</Button>
            <Button 
              size="sm" 
              className="h-8 text-xs"
              onClick={() => {
                if (odc && onEdit) {
                  onClose()
                  onEdit(odc)
                }
              }}
            >
              Edit ODC
            </Button>
          </div>
        </div>
      </DialogContent>

      {/* Sub-Dialog untuk Hubungkan ODP */}
      <Dialog open={selectedPortToConnect !== null} onOpenChange={(v) => !v && setSelectedPortToConnect(null)}>
        <DialogContent className='sm:max-w-[360px] p-4 rounded-2xl z-[9999] pointer-events-auto'>
          <DialogHeader>
            <DialogTitle className='text-sm font-bold'>Hubungkan ODP ke Port {selectedPortToConnect}</DialogTitle>
          </DialogHeader>
          <div className='space-y-4 pt-2'>
            <p className='text-xs text-muted-foreground'>Pilih ODP yang akan dihubungkan ke port {selectedPortToConnect} pada ODC {odc.name}:</p>
            <Select value={selectedOdpIdToConnect} onValueChange={setSelectedOdpIdToConnect}>
              <SelectTrigger className='w-full text-xs h-9'>
                <SelectValue placeholder='Pilih ODP...' />
              </SelectTrigger>
              <SelectContent className='z-[10000] pointer-events-auto'>
                {availableOdps.map((o: any) => (
                  <SelectItem key={o.id} value={String(o.id)} className='text-xs'>
                    {o.name}
                  </SelectItem>
                ))}
                {availableOdps.length === 0 && (
                  <SelectItem value="none" disabled className='text-xs italic'>
                    Tidak ada ODP yang tersedia
                  </SelectItem>
                )}
              </SelectContent>
            </Select>
            <div className='flex justify-end gap-2 pt-2'>
              <Button variant='ghost' size='sm' onClick={() => setSelectedPortToConnect(null)} className='h-8 text-xs'>Batal</Button>
              <Button 
                size='sm' 
                className='h-8 text-xs' 
                disabled={!selectedOdpIdToConnect || selectedOdpIdToConnect === 'none'}
                onClick={async () => {
                  if (!selectedOdpIdToConnect || selectedPortToConnect === null) return
                  try {
                    await api.post('/bulk_update_odp.php', {
                      ids: [Number(selectedOdpIdToConnect)],
                      updates: {
                        odc_id: odc.id,
                        core_number: selectedPortToConnect
                      }
                    })
                    toast.success('ODP berhasil dihubungkan ke port!')
                    setSelectedPortToConnect(null)
                    setSelectedOdpIdToConnect('')
                    queryClient.invalidateQueries({ queryKey: ['odps', odc.router_id] })
                  } catch (err) {
                    toast.error('Gagal menghubungkan ODP')
                  }
                }}
              >
                Hubungkan
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </Dialog>
  )
}
