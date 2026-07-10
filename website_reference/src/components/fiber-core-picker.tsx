import { useState, useEffect } from 'react'
import { cn } from '@/lib/utils'
import {
  FIBER_COLORS,
  CABLE_CORE_OPTIONS,
  getTubeCount,
  getCoreNumberFromSelection,
  getSelectionFromCoreNumber,
  inferCableSizeFromCoreNumber,
} from '@/lib/fiber-color'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { FormLabel } from '@/components/ui/form'

interface FiberCorePickerProps {
  value: number | null | undefined
  onChange: (coreNumber: number | null) => void
  onCableColorChange?: (colorId: number | null) => void
  label?: string
}

export function FiberCorePicker({
  value,
  onChange,
  onCableColorChange,
  label = 'Nomor Core (Uplink/Backbone)',
}: FiberCorePickerProps) {
  const [cableTotal, setCableTotal] = useState<number>(() => {
    if (value) return inferCableSizeFromCoreNumber(value)
    return 1
  })

  const [selectedTube, setSelectedTube] = useState<number>(() => {
    if (value) return getSelectionFromCoreNumber(value).tubeIndex
    return 0
  })

  const [selectedCore, setSelectedCore] = useState<number>(() => {
    if (value) return getSelectionFromCoreNumber(value).coreIndex
    return 0
  })

  const isMultiTube = cableTotal > 12
  const tubeCount = getTubeCount(cableTotal)
  const visibleCores = isMultiTube ? 12 : cableTotal

  // Sinkronisasi value prop ke state lokal saat form reset / ganti data
  useEffect(() => {
    if (value) {
      // Mode edit: sinkronkan total kabel, tube, dan core
      const currentCableTotal = inferCableSizeFromCoreNumber(value)
      setCableTotal(prev => currentCableTotal > prev ? currentCableTotal : prev)
      
      const { tubeIndex, coreIndex } = getSelectionFromCoreNumber(value)
      setSelectedTube(tubeIndex)
      setSelectedCore(coreIndex)
      
      onCableColorChange?.(coreIndex + 1)
    } else {
      // Mode tambah baru: default Biru
      onChange(1)
      onCableColorChange?.(1)
    }
  }, [value])

  // Hitung core_number & warna kabel setiap kali pilihan berubah
  useEffect(() => {
    const resolvedTube = isMultiTube ? selectedTube : 0
    const coreNum = getCoreNumberFromSelection(resolvedTube, selectedCore)
    onChange(coreNum)
    // Warna kabel selalu = warna core yang dipilih (bukan warna tube)
    const colorId = selectedCore + 1
    onCableColorChange?.(colorId)
  }, [selectedTube, selectedCore, isMultiTube])

  return (
    <div className="space-y-3">
      <FormLabel className="text-xs font-bold">{label}</FormLabel>

      {/* Pilih total core kabel */}
      <div className="space-y-1">
        <p className="text-[10px] text-muted-foreground font-semibold uppercase">Total Core Kabel</p>
        <Select
          value={String(cableTotal)}
          onValueChange={(v) => {
            setCableTotal(Number(v))
            setSelectedTube(0)
            setSelectedCore(0)
          }}
        >
          <SelectTrigger className="h-8 text-xs font-semibold">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {CABLE_CORE_OPTIONS.map((size) => (
              <SelectItem key={size} value={String(size)}>
                {size} Core {size <= 12 ? '(1 tube)' : `(${getTubeCount(size)} tube @ 12)`}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Pilih Tube — hanya untuk kabel multi-tube */}
      {isMultiTube && (
        <div className="space-y-1.5">
          <p className="text-[10px] text-muted-foreground font-semibold uppercase">Pilih Tube</p>
          <div className="grid grid-cols-4 gap-2 px-0.5 py-0.5">
            {Array.from({ length: tubeCount }, (_, i) => {
              const color = FIBER_COLORS[i % 12]
              const isSelected = selectedTube === i
              return (
                <button
                  key={i}
                  type="button"
                  onClick={() => {
                    setSelectedTube(i)
                    setSelectedCore(0)
                  }}
                  className={cn(
                    'flex flex-col items-center gap-1 p-1.5 rounded-lg border text-center text-[9px] font-bold transition-colors',
                    isSelected
                      ? 'border-2'
                      : 'border-border/60 bg-muted/20 hover:bg-muted/50'
                  )}
                  style={isSelected ? {
                    borderColor: color.code,
                    backgroundColor: color.code + '15',
                    boxShadow: `0 0 0 2px ${color.code}`,
                  } : {}}
                >
                  <div
                    className="h-5 w-5 rounded-full shrink-0"
                    style={{ backgroundColor: color.code }}
                  />
                  <span className={cn('leading-none', isSelected ? 'text-slate-900 dark:text-white' : 'text-muted-foreground')}>
                    T{i + 1}
                  </span>
                  <span className="text-[8px] text-muted-foreground leading-none truncate w-full">{color.name}</span>
                </button>
              )
            })}
          </div>
        </div>
      )}

      {/* Pilih Core */}
      <div className="space-y-1.5">
        <p className="text-[10px] text-muted-foreground font-semibold uppercase">
          {isMultiTube
            ? `Pilih Core dalam Tube ${selectedTube + 1} (${FIBER_COLORS[selectedTube % 12].name})`
            : 'Pilih Core'}
        </p>
        <div className="grid grid-cols-6 gap-2 px-0.5 py-0.5">
          {Array.from({ length: visibleCores }, (_, i) => {
            const color = FIBER_COLORS[i]
            const isSelected = selectedCore === i
            return (
              <button
                key={i}
                type="button"
                onClick={() => setSelectedCore(i)}
                className={cn(
                  'flex flex-col items-center justify-center p-2 rounded-xl border text-center text-[9px] font-bold transition-colors aspect-square',
                  isSelected
                    ? 'border-2'
                    : 'border-border/60 bg-muted/20 hover:bg-muted/50'
                )}
                style={isSelected ? {
                  borderColor: color.code,
                  backgroundColor: color.code + '15',
                  boxShadow: `0 0 0 2px ${color.code}`,
                } : {}}
                title={`Core ${i + 1} - ${color.name}`}
              >
                <div
                  className={cn(
                    'h-6 w-6 rounded-full shrink-0',
                    color.name === 'Putih' && 'ring-1 ring-gray-300'
                  )}
                  style={{ backgroundColor: color.code }}
                />
                <span className="text-[8px] text-muted-foreground leading-none truncate w-full">{color.name}</span>
              </button>
            )
          })}
        </div>
      </div>
    </div>
  )
}
