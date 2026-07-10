import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { MapPin, Share2, Zap } from 'lucide-react'
import { api } from '@/lib/api'
import { getFiberColors } from '@/lib/fiber-color'
import { cn } from '@/lib/utils'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { ScrollArea } from '@/components/ui/scroll-area'
import { type ODP } from '../data/schema'

interface Props {
  isOpen: boolean
  onClose: () => void
  odp: ODP | null
  onEdit?: (odp: ODP) => void
  onDelete?: (odp: ODP) => void
}

export function ODPDetailDialog({
  isOpen,
  onClose,
  odp,
  onEdit,
  onDelete,
}: Props) {
  const { data: acsDevices } = useQuery({
    queryKey: ['genieacs-devices'],
    queryFn: async () => {
      const projection = [
        '_id',
        'VirtualParameters.RXPower',
        'VirtualParameters.pppoeUsername',
      ].join(',')
      const res = await api.get(
        `/genieacs_proxy.php?path=/devices&projection=${projection}`
      )
      return res.data || []
    },
    enabled: isOpen && !!odp,
    refetchInterval: 15000,
    staleTime: 10000,
  })

  // Helper getNestedParam
  const getNestedParam = (obj: any, path: string) => {
    if (!obj) return ''
    const parts = path.split('.')
    let current = obj
    for (const part of parts) {
      if (current && typeof current === 'object' && part in current) {
        current = current[part]
      } else {
        return ''
      }
    }
    if (current === null || current === undefined) return ''
    if (typeof current === 'string' || typeof current === 'number')
      return String(current)
    if (current._value !== undefined) return String(current._value)
    if (current.value !== undefined) return String(current.value)
    return ''
  }

  // Check if this is a ratio splitter
  const isRatioSplitter = odp?.type === 'ratio'

  // Extract tap and thru percents
  const parsedRatio = useMemo(() => {
    if (!odp || !isRatioSplitter) return null
    
    // First try database values
    let tap = Number(odp.ratio_used) || 0
    let thru = Number(odp.ratio_total) || 0
    
    // If not valid, try parsing from name (e.g. ODP Ratio 10/90)
    if (tap <= 0 || thru <= 0 || (tap + thru !== 100)) {
      const match = odp.name.match(/(\d+)[/-](\d+)/)
      if (match) {
        const val1 = parseInt(match[1])
        const val2 = parseInt(match[2])
        if (val1 + val2 === 100) {
          tap = Math.min(val1, val2)
          thru = Math.max(val1, val2)
        }
      }
    }
    
    // Fallback default to 10 / 90
    if (tap <= 0 || thru <= 0 || (tap + thru !== 100)) {
      tap = 10
      thru = 90
    }
    
    return { tap, thru }
  }, [odp, isRatioSplitter])

  // Calculate remaining capacity
  let totalCapacity = 0
  if (odp?.type === 'splitter') {
    const parts = odp.splitter_type?.split(':')
    totalCapacity = parts && parts.length > 1 ? parseInt(parts[1]) : 0
  } else if (isRatioSplitter) {
    totalCapacity = odp?.capacity || 8
  } else {
    totalCapacity = odp?.ratio_total || 0
  }
  const remaining = Math.max(0, totalCapacity - (odp?.total_users || 0))

  // Map users with live signal
  const mappedUsersList = useMemo(() => {
    if (!odp?.users_list) return []
    return odp.users_list.map((u: any) => {
      const acsDevice = acsDevices?.find(
        (d: any) =>
          getNestedParam(d, 'VirtualParameters.pppoeUsername') === u.username
      )
      const rx = acsDevice
        ? getNestedParam(acsDevice, 'VirtualParameters.RXPower')
        : ''
      return {
        ...u,
        redaman_live: rx ? String(rx) : null,
      }
    })
  }, [odp?.users_list, acsDevices])

  // Build Port Grid
  const ports = useMemo(() => {
    if (!odp) return []
    const grid = Array.from({ length: totalCapacity }, (_, i) => ({
      portNum: i + 1,
      user: null as any,
    }))
    const unassigned: any[] = []
    mappedUsersList.forEach((u: any) => {
      const p = u.odp_port
      if (p && p >= 1 && p <= totalCapacity) {
        if (!grid[p - 1].user) {
          grid[p - 1].user = u
        } else {
          unassigned.push(u)
        }
      } else {
        unassigned.push(u)
      }
    })
    unassigned.forEach((u) => {
      const emptyIdx = grid.findIndex((slot) => !slot.user)
      if (emptyIdx !== -1) {
        grid[emptyIdx].user = u
      }
    })
    return grid
  }, [odp, totalCapacity, mappedUsersList])

  const fiberInfo = useMemo(
    () => getFiberColors(odp?.core_number),
    [odp?.core_number]
  )

  const sourceRxPower = odp?.rx_power
    ? parseFloat(odp.rx_power as string)
    : null

  // Helper: Splitter insertion loss calculation
  const splitterLossDb = useMemo(() => {
    if (!odp || odp.type !== 'splitter') return null
    let ratio = 0
    if (odp.splitter_type) {
      const parts = odp.splitter_type.split(':')
      if (parts.length === 2) ratio = parseInt(parts[1])
    }
    if (!ratio || ratio <= 1) return null
    const standardLoss: Record<number, number> = {
      2: 3,
      4: 7,
      8: 10,
      16: 14,
      32: 17,
      64: 20,
    }
    if (standardLoss[ratio] !== undefined)
      return { ratio, loss: standardLoss[ratio] }
    return { ratio, loss: Math.round(10 * Math.log10(ratio) + 0.5) }
  }, [odp])

  const outputPerPort = useMemo(() => {
    if (sourceRxPower === null || isNaN(sourceRxPower) || !splitterLossDb)
      return null
    return (sourceRxPower - splitterLossDb.loss).toFixed(1)
  }, [sourceRxPower, splitterLossDb])

  // Calculations for Ratio Splitter (Unbalanced/Asymmetric Splitter)
  const ratioDetails = useMemo(() => {
    if (!odp || !isRatioSplitter || !parsedRatio) return null
    const tapPercent = parsedRatio.tap
    const thruPercent = parsedRatio.thru

    // Loss formulas from Excel Sheet: -10 * log10(percentage / 100) + 0.25
    const tapLoss = parseFloat((-10 * Math.log10(tapPercent / 100) + 0.25).toFixed(2))
    const thruLoss = parseFloat((-10 * Math.log10(thruPercent / 100) + 0.25).toFixed(2))

    const tapOutput = sourceRxPower !== null ? (sourceRxPower - tapLoss).toFixed(2) : null
    const thruOutput = sourceRxPower !== null ? (sourceRxPower - thruLoss).toFixed(2) : null

    // Local ODP connects to larger percent, next ODP terusan connects to smaller percent
    const isTapLarger = tapPercent > thruPercent
    const localOutputPower = isTapLarger ? tapOutput : thruOutput
    const localOutputPercent = isTapLarger ? tapPercent : thruPercent

    const forwardOutputPower = isTapLarger ? thruOutput : tapOutput
    const forwardOutputPercent = isTapLarger ? thruPercent : tapPercent

    // Local splitter loss based on capacity (default: 8)
    const localSplitterCapacity = odp.capacity || 8
    const localLossMap: Record<number, number> = {
      2: 3,
      4: 7,
      8: 10,
      16: 14,
      32: 17,
      64: 20,
    }
    const localSplitterLoss = localLossMap[localSplitterCapacity] || 10

    const customerPortOutput = localOutputPower !== null ? (parseFloat(localOutputPower) - localSplitterLoss).toFixed(2) : null

    return {
      tapPercent,
      thruPercent,
      tapLoss,
      thruLoss,
      tapOutput,
      thruOutput,
      localSplitterCapacity,
      localSplitterLoss,
      customerPortOutput,
      localOutputPercent,
      forwardOutputPercent,
      forwardOutputPower,
    }
  }, [odp, isRatioSplitter, parsedRatio, sourceRxPower])

  if (!odp) return null

  return (
    <Dialog open={isOpen} onOpenChange={(v) => !v && onClose()}>
      <DialogContent className='max-w-sm gap-0 overflow-hidden p-0'>
        <DialogHeader className='border-b p-4'>
          <DialogTitle className='flex items-center gap-2 text-base font-semibold'>
            <Share2 className='h-4 w-4 text-primary' />
            Detail ODP
          </DialogTitle>
        </DialogHeader>

        <ScrollArea className='max-h-[70vh]'>
          <div className='space-y-4 p-4'>
            {/* Header identity */}
            <div className='flex items-start justify-between border-b pb-3'>
              <div className='flex-1 min-w-0'>
                <p className='text-xs text-muted-foreground'>Nama ODP</p>
                <p className='text-lg leading-tight font-bold break-words'>{odp.name}</p>
                {/* Badge stat di bawah nama */}
                <div className='flex items-center gap-2 mt-1.5 flex-wrap'>
                  <span className='inline-flex items-center gap-1 text-[10px] font-bold bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 px-2 py-0.5 rounded-full'>
                    <span className='h-1.5 w-1.5 rounded-full bg-green-500 inline-block' />
                    {odp.total_users || 0} Terkoneksi
                  </span>
                  <span className='inline-flex items-center gap-1 text-[10px] font-bold bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400 px-2 py-0.5 rounded-full'>
                    {remaining} Sisa Port
                  </span>
                </div>
              </div>
              <div className='text-right shrink-0 ml-2'>
                <p className='text-xs text-muted-foreground'>Tipe & Kapasitas</p>
                <Badge variant='outline' className='h-5 mt-0.5 text-[10px] capitalize font-bold bg-muted/50'>
                  {odp.type === 'splitter'
                    ? `Splitter ${odp.splitter_type || '-'}`
                    : `Ratio ${odp.ratio_used}/${odp.ratio_total}`}
                </Badge>
              </div>
            </div>

            <div className='grid grid-cols-2 gap-3'>
              {/* Specs Info */}
              <div className='space-y-2 rounded-lg border border-border/50 bg-muted/30 p-3'>
                <div className='flex items-center justify-between text-xs'>
                  <span className='text-muted-foreground'>Sisa Port</span>
                  <span className='font-bold text-blue-600'>
                    {remaining} Port
                  </span>
                </div>
                {odp.gpon_type && (
                  <div className='flex items-center justify-between border-t pt-1 text-xs'>
                    <span className='text-muted-foreground'>GPON/EPON</span>
                    <span className='font-bold text-slate-700'>
                      {odp.gpon_type}
                    </span>
                  </div>
                )}
                {odp.core_number !== null && odp.core_number !== undefined && fiberInfo && (
                  <>
                    <div className='flex items-center justify-between border-t pt-1 text-xs'>
                      <span className='text-muted-foreground'>
                        Warna Tube
                      </span>
                      <div className='text-slate-750 flex items-center gap-1.5 font-bold'>
                        <div
                          className='h-2.5 w-2.5 shrink-0 rounded-full border border-black/10'
                          style={{ backgroundColor: fiberInfo.tube.code }}
                        />
                        <span>
                          {fiberInfo.tube.name}
                        </span>
                      </div>
                    </div>
                    <div className='flex items-center justify-between border-t pt-1 text-xs'>
                      <span className='text-muted-foreground'>
                        Warna Core
                      </span>
                      <div className='text-slate-750 flex items-center gap-1.5 font-bold'>
                        <div
                          className='h-2.5 w-2.5 shrink-0 rounded-full border border-black/10'
                          style={{ backgroundColor: fiberInfo.core.code }}
                        />
                        <span>
                          {fiberInfo.core.name}
                        </span>
                      </div>
                    </div>
                  </>
                )}
              </div>

              {/* Usage Info */}
              <div className='space-y-2 rounded-lg border border-green-500/10 bg-green-500/5 p-3'>
                {odp.rx_power && (
                  <div className='flex items-center justify-between pb-1.5 border-b border-green-500/10 text-xs'>
                    <span className='text-green-800 dark:text-green-300 font-semibold'>Rx Sumber</span>
                    <span className='font-mono font-bold text-amber-700'>
                      {odp.rx_power} dBm
                    </span>
                  </div>
                )}
                  {/* Rx sumber saja di sini, terkoneksi sudah di header */}
                {odp.type === 'ratio' && ratioDetails ? (
                  <>
                    <div className='flex items-center justify-between border-t pt-1 text-xs'>
                      <span className='text-muted-foreground'>
                        Loss {ratioDetails.tapPercent}%
                      </span>
                      <span className='font-mono font-bold text-orange-600'>
                        +{ratioDetails.tapLoss} dB
                      </span>
                    </div>
                    {ratioDetails.tapOutput !== null && (
                      <div className='flex items-center justify-between border-t pt-1 text-xs'>
                        <span className='text-muted-foreground'>Output {ratioDetails.tapPercent}%</span>
                        <span
                          className={cn(
                            'font-mono font-bold',
                            parseFloat(ratioDetails.tapOutput) < -25
                              ? 'text-red-600'
                              : 'text-amber-700'
                          )}
                        >
                          {ratioDetails.tapOutput} dBm
                        </span>
                      </div>
                    )}
                    <div className='flex items-center justify-between border-t pt-1 text-xs'>
                      <span className='text-muted-foreground'>
                        Loss {ratioDetails.thruPercent}%
                      </span>
                      <span className='font-mono font-bold text-orange-600'>
                        +{ratioDetails.thruLoss} dB
                      </span>
                    </div>
                    {ratioDetails.thruOutput !== null && (
                      <div className='flex items-center justify-between border-t pt-1 text-xs'>
                        <span className='text-muted-foreground'>Output {ratioDetails.thruPercent}%</span>
                        <span
                          className={cn(
                            'font-mono font-bold',
                            parseFloat(ratioDetails.thruOutput) < -25
                              ? 'text-red-600'
                              : 'text-green-700'
                          )}
                        >
                          {ratioDetails.thruOutput} dBm
                        </span>
                      </div>
                    )}
                    <div className='flex items-center justify-between border-t pt-1 text-xs bg-slate-50/50 dark:bg-slate-900/50 px-1 py-0.5 rounded'>
                      <span className='text-muted-foreground font-semibold'>
                        Splitter Lokal (1:{ratioDetails.localSplitterCapacity})
                      </span>
                      <span className='font-mono font-bold text-orange-600'>
                        +{ratioDetails.localSplitterLoss} dB
                      </span>
                    </div>
                    {ratioDetails.customerPortOutput !== null && (
                      <div className='flex items-center justify-between border-t pt-1 text-xs bg-emerald-50/30 dark:bg-emerald-950/10 px-1 py-0.5 rounded'>
                        <span className='text-emerald-700 dark:text-emerald-400 font-bold'>
                          Output Pelanggan
                        </span>
                        <span
                          className={cn(
                            'font-mono font-black',
                            parseFloat(ratioDetails.customerPortOutput) < -25
                              ? 'text-red-600'
                              : 'text-emerald-700 dark:text-emerald-400'
                          )}
                        >
                          {ratioDetails.customerPortOutput} dBm
                        </span>
                      </div>
                    )}
                    {ratioDetails.forwardOutputPower !== null && (
                      <div className='flex items-center justify-between border-t pt-1 text-xs bg-blue-50/30 dark:bg-blue-950/10 px-1 py-0.5 rounded'>
                        <span className='text-blue-700 dark:text-blue-400 font-bold'>
                          Terusan ke ODP Hilir ({ratioDetails.forwardOutputPercent}%)
                        </span>
                        <span
                          className={cn(
                            'font-mono font-black',
                            parseFloat(ratioDetails.forwardOutputPower) < -25
                              ? 'text-red-600'
                              : 'text-blue-700 dark:text-blue-400'
                          )}
                        >
                          {ratioDetails.forwardOutputPower} dBm
                        </span>
                      </div>
                    )}
                  </>
                ) : (
                  <>
                    {splitterLossDb && (
                      <div className='flex items-center justify-between border-t pt-1 text-xs'>
                        <span className='text-muted-foreground'>
                          Insertion Loss
                        </span>
                        <span className='font-mono font-bold text-orange-600'>
                          +{splitterLossDb.loss} dB
                        </span>
                      </div>
                    )}
                    {outputPerPort !== null && (
                      <div className='flex items-center justify-between border-t pt-1 text-xs'>
                        <span className='text-muted-foreground'>Output/Port</span>
                        <span
                          className={cn(
                            'font-mono font-bold',
                            parseFloat(outputPerPort) < -25
                              ? 'text-red-600'
                              : 'text-green-700'
                          )}
                        >
                          {outputPerPort} dBm
                        </span>
                      </div>
                    )}
                  </>
                )}
              </div>
            </div>

            {/* Visual Port Grid */}
            <div className='space-y-2'>
              <p className='px-1 text-[10px] font-bold text-muted-foreground uppercase'>
                Visual Port Grid
              </p>
              <div className='grid grid-cols-4 gap-2'>
                {ports.map((port) => {
                  const hasUser = !!port.user
                  const redamanLiveVal = port.user?.redaman_live
                    ? parseFloat(port.user.redaman_live)
                    : null
                  const redamanManVal = port.user?.redaman
                    ? parseFloat(port.user.redaman)
                    : null
                  const rx = redamanLiveVal ?? redamanManVal
                  const isCritical = rx !== null && rx < -25

                  return (
                    <div
                      key={port.portNum}
                      className={cn(
                        'relative flex h-16 flex-col justify-between overflow-hidden rounded-xl border p-2 text-center transition-all select-none',
                        hasUser
                          ? isCritical
                            ? 'border-rose-200 bg-rose-50 text-rose-800 dark:border-rose-900/50 dark:bg-rose-950/20 dark:text-rose-300'
                            : 'border-blue-200 bg-blue-50 text-blue-800 dark:border-blue-900/50 dark:bg-blue-950/20 dark:text-blue-300'
                          : 'border-dashed border-emerald-200 bg-emerald-50/50 text-emerald-700 dark:border-emerald-900/30 dark:bg-emerald-950/10 dark:text-emerald-400'
                      )}
                    >
                      <span
                        className={cn(
                          'absolute top-1 left-1 flex h-3.5 w-3.5 items-center justify-center rounded-full border text-[8px] font-black',
                          hasUser
                            ? isCritical
                              ? 'text-rose-850 border-rose-300 bg-rose-200 dark:border-rose-800 dark:bg-rose-900 dark:text-rose-200'
                              : 'text-blue-850 border-blue-300 bg-blue-200 dark:border-blue-800 dark:bg-blue-900 dark:text-blue-200'
                            : 'border-emerald-200 bg-emerald-100 text-emerald-800 dark:border-emerald-800 dark:bg-emerald-900 dark:text-emerald-200'
                        )}
                      >
                        {port.portNum}
                      </span>

                      <div className='mt-3.5 flex flex-1 flex-col justify-center'>
                        {hasUser ? (
                          <>
                            <span
                              className='max-w-full truncate px-0.5 text-[9px] font-bold'
                              title={port.user.username}
                            >
                              {port.user.username}
                            </span>
                            <span className='font-mono text-[8px] font-medium opacity-90'>
                              {port.user.redaman_live
                                ? `${port.user.redaman_live} dB`
                                : port.user.redaman
                                  ? `${port.user.redaman} dB`
                                  : '-'}
                            </span>
                          </>
                        ) : (
                          <span className='text-[8px] font-black tracking-wider text-emerald-600/70 uppercase dark:text-emerald-400/50'>
                            KOSONG
                          </span>
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>

            {/* Splitter Attenuation Calculation Card */}
            {odp.type === 'ratio' && ratioDetails ? (
              <div className='space-y-2 rounded-xl border border-orange-200 bg-linear-to-br from-orange-50 to-amber-50 p-3'>
                <div className='flex items-center gap-1.5'>
                  <Zap className='h-3.5 w-3.5 text-orange-500' />
                  <p className='text-[10px] font-black text-orange-700 uppercase'>
                    Kalkulasi Asymmetric Splitter ({ratioDetails.tapPercent}/{ratioDetails.thruPercent})
                  </p>
                </div>
                <div className='grid grid-cols-4 gap-1 text-center'>
                  <div className='rounded-lg border border-orange-100 bg-white p-1.5'>
                    <p className='mb-0.5 text-[8px] text-muted-foreground'>
                      Rx Sumber
                    </p>
                    <p className='font-mono text-[10px] font-black text-amber-700'>
                      {sourceRxPower !== null ? `${sourceRxPower} dBm` : '–'}
                    </p>
                  </div>
                  <div className='rounded-lg border border-orange-200 bg-orange-100 p-1.5'>
                    <p className='mb-0.5 text-[8px] text-orange-700'>
                      TAP ({ratioDetails.tapPercent}%)
                    </p>
                    <p className='font-mono text-[10px] font-black text-orange-600'>
                      {ratioDetails.tapOutput !== null ? `${ratioDetails.tapOutput} dBm` : '–'}
                    </p>
                    <p className='text-[7px] text-orange-500'>Loss: +{ratioDetails.tapLoss} dB</p>
                  </div>
                  <div className='rounded-lg border border-orange-200 bg-orange-100 p-1.5'>
                    <p className='mb-0.5 text-[8px] text-orange-700'>
                      THRU ({ratioDetails.thruPercent}%)
                    </p>
                    <p className='font-mono text-[10px] font-black text-orange-600'>
                      {ratioDetails.thruOutput !== null ? `${ratioDetails.thruOutput} dBm` : '–'}
                    </p>
                    <p className='text-[7px] text-orange-500'>Loss: +{ratioDetails.thruLoss} dB</p>
                  </div>
                  <div
                    className={cn(
                      'rounded-lg border p-1.5',
                      ratioDetails.customerPortOutput !== null && parseFloat(ratioDetails.customerPortOutput) < -25
                        ? 'border-red-200 bg-red-50'
                        : 'border-green-200 bg-green-50'
                    )}
                  >
                    <p className='mb-0.5 text-[8px] text-muted-foreground'>
                      Output/Port
                    </p>
                    <p
                      className={cn(
                        'font-mono text-[10px] font-black',
                        ratioDetails.customerPortOutput !== null &&
                          parseFloat(ratioDetails.customerPortOutput) < -25
                          ? 'text-red-600'
                          : 'text-green-700'
                      )}
                    >
                      {ratioDetails.customerPortOutput !== null ? `${ratioDetails.customerPortOutput} dBm` : '–'}
                    </p>
                    <p className='text-[7px] text-muted-foreground'>
                      Splitter 1:{ratioDetails.localSplitterCapacity}
                    </p>
                  </div>
                </div>
                <p className='text-center text-[8px] leading-relaxed text-muted-foreground'>
                  {sourceRxPower !== null
                    ? `TAP: ${sourceRxPower} dBm − ${ratioDetails.tapLoss} dB = ${ratioDetails.tapOutput} dBm. Output/Port: ${ratioDetails.tapOutput} dBm − Loss Splitter 1:${ratioDetails.localSplitterCapacity} (${ratioDetails.localSplitterLoss} dB) = ${ratioDetails.customerPortOutput} dBm.`
                    : `Loss Tap: ${ratioDetails.tapLoss} dB | Loss Thru: ${ratioDetails.thruLoss} dB | Loss Splitter Lokal: ${ratioDetails.localSplitterLoss} dB`}
                </p>
              </div>
            ) : splitterLossDb ? (
              <div className='space-y-2 rounded-xl border border-orange-200 bg-linear-to-br from-orange-50 to-amber-50 p-3'>
                <div className='flex items-center gap-1.5'>
                  <Zap className='h-3.5 w-3.5 text-orange-500' />
                  <p className='text-[10px] font-black text-orange-700 uppercase'>
                    Kalkulasi Redaman Splitter
                  </p>
                </div>
                <div className='grid grid-cols-3 gap-1.5 text-center'>
                  <div className='rounded-lg border border-orange-100 bg-white p-2'>
                    <p className='mb-0.5 text-[9px] text-muted-foreground'>
                      Rx Sumber
                    </p>
                    <p className='font-mono text-xs font-black text-amber-700'>
                      {sourceRxPower !== null ? `${sourceRxPower} dBm` : '–'}
                    </p>
                  </div>
                  <div className='rounded-lg border border-orange-200 bg-orange-100 p-2'>
                    <p className='mb-0.5 text-[9px] text-orange-700'>
                      Loss 1:{splitterLossDb.ratio}
                    </p>
                    <p className='font-mono text-xs font-black text-orange-600'>
                      +{splitterLossDb.loss} dB
                    </p>
                  </div>
                  <div
                    className={cn(
                      'rounded-lg border p-2',
                      outputPerPort !== null && parseFloat(outputPerPort) < -25
                        ? 'border-red-200 bg-red-50'
                        : 'border-green-200 bg-green-50'
                    )}
                  >
                    <p className='mb-0.5 text-[9px] text-muted-foreground'>
                      Output/Port
                    </p>
                    <p
                      className={cn(
                        'font-mono text-xs font-black',
                        outputPerPort !== null &&
                          parseFloat(outputPerPort) < -25
                          ? 'text-red-600'
                          : 'text-green-700'
                      )}
                    >
                      {outputPerPort !== null ? `${outputPerPort} dBm` : '–'}
                    </p>
                  </div>
                </div>
                <p className='text-center text-[9px] leading-relaxed text-muted-foreground'>
                  {sourceRxPower !== null
                    ? `${sourceRxPower} dBm − ${splitterLossDb.loss} dB (1:${splitterLossDb.ratio}) = ${outputPerPort} dBm per port`
                    : `Insertion loss splitter 1:${splitterLossDb.ratio} = ${splitterLossDb.loss} dB`}
                </p>
              </div>
            ) : null}

            {/* Location Section */}
            <div className='space-y-2'>
              <p className='px-1 text-[10px] font-bold text-muted-foreground uppercase'>
                Lokasi & Alamat
              </p>
              <div className='space-y-3 rounded-lg border border-border/50 bg-muted/30 p-3'>
                <p className='text-xs leading-relaxed font-semibold text-slate-700'>
                  {odp.location || 'Tidak ada keterangan alamat'}
                </p>

                {odp.maps_link && (
                  <Button
                    variant='outline'
                    size='sm'
                    className='h-8 w-full gap-2 bg-white text-[10px] transition-colors hover:border-blue-200 hover:bg-blue-50 hover:text-blue-600'
                    onClick={() => window.open(odp.maps_link!, '_blank')}
                  >
                    <MapPin className='h-3 w-3 text-red-500' />
                    Buka di Google Maps
                  </Button>
                )}
              </div>
            </div>
          </div>
        </ScrollArea>
        <div className='flex items-center justify-between border-t bg-muted/20 p-3'>
          <Button
            variant='ghost'
            size='sm'
            className='h-8 text-xs text-destructive hover:bg-destructive/10 hover:text-destructive'
            onClick={() => {
              if (odp && onDelete) {
                onClose()
                onDelete(odp)
              }
            }}
          >
            Hapus ODP
          </Button>
          <div className='flex gap-2'>
            <Button
              variant='ghost'
              size='sm'
              onClick={onClose}
              className='h-8 text-xs'
            >
              Tutup
            </Button>
            <Button
              size='sm'
              className='h-8 text-xs'
              onClick={() => {
                if (odp && onEdit) {
                  onClose()
                  onEdit(odp)
                }
              }}
            >
              Edit ODP
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
