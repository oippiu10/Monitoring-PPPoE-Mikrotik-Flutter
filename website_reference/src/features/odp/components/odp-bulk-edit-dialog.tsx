import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { api } from '@/lib/api'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Checkbox } from '@/components/ui/checkbox'
import { useRouterStore } from '@/stores/router-store'
import { Network, Building2, Settings2, Layers, Activity, Zap, Share2 } from 'lucide-react'

interface Props {
  isOpen: boolean
  onClose: () => void
  selectedIds: number[]
}

export function ODPBulkEditDialog({ isOpen, onClose, selectedIds }: Props) {
  const queryClient = useQueryClient()
  const { activeRouter } = useRouterStore()

  // --- Field flags ---
  const [updateOdc, setUpdateOdc]       = useState(false)
  const [odcAction, setOdcAction]       = useState<'move' | 'detach'>('move')
  const [targetOdcId, setTargetOdcId]   = useState<string>('')

  // Gabungan Tipe & Kapasitas
  const [updateTipeKapasitas, setUpdateTipeKapasitas] = useState(false)
  const [type, setType]                 = useState<'splitter' | 'ratio'>('splitter')
  const [splitterType, setSplitterType]       = useState('1:8')
  const [ratioUsed, setRatioUsed]             = useState(50)
  const [ratioTotal, setRatioTotal]           = useState(50)

  // --- GPON / EPON ---
  const [updateGpon, setUpdateGpon]     = useState(false)
  const [gponType, setGponType]         = useState('GPON')

  // --- Rx Sumber ---
  const [updateRx, setUpdateRx]         = useState(false)
  const [rxPower, setRxPower]           = useState('')

  // --- Sumber Terusan (ODP) ---
  const [updateParent, setUpdateParent] = useState(false)
  const [parentAction, setParentAction] = useState<'move' | 'detach'>('move')
  const [targetParentId, setTargetParentId] = useState<string>('')

  // --- Load ODC list ---
  const { data: odcList = [] } = useQuery<any[]>({
    queryKey: ['odcs', activeRouter?.id],
    queryFn: async () => {
      const res = await api.get('/odc.php', { params: { router_id: activeRouter?.id } })
      return res.data.data || []
    },
    enabled: !!activeRouter && isOpen,
  })

  // --- Load ODP list ---
  const { data: odpList = [] } = useQuery<any[]>({
    queryKey: ['odps', activeRouter?.id],
    queryFn: async () => {
      const res = await api.get('/odp.php', { params: { router_id: activeRouter?.id } })
      return res.data.data || []
    },
    enabled: !!activeRouter && isOpen,
  })

  const mutation = useMutation({
    mutationFn: async () => {
      const updates: any = {}

      if (updateOdc) {
        if (odcAction === 'detach') {
          updates.odc_id = null
        } else if (odcAction === 'move' && targetOdcId) {
          updates.odc_id = parseInt(targetOdcId)
          updates.parent_id = null // Otomatis lepas parent jika dipindah ke ODC
        }
      }
      
      if (updateParent) {
        if (parentAction === 'detach') {
          updates.parent_id = null
        } else if (parentAction === 'move' && targetParentId) {
          updates.parent_id = parseInt(targetParentId)
          updates.odc_id = null // Otomatis lepas ODC jika dipindah ke ODP
        }
      }

      if (updateTipeKapasitas) {
        updates.type = type
        if (type === 'splitter') updates.splitter_type = splitterType
        else { updates.ratio_used = ratioUsed; updates.ratio_total = ratioTotal }
      }

      if (updateGpon) updates.gpon_type = gponType
      if (updateRx)   updates.rx_power  = rxPower || null

      const res = await api.post('/bulk_update_odp.php', {
        ids: selectedIds,
        updates,
      })
      return res.data
    },
    onSuccess: (data) => {
      if (data.success) {
        toast.success(data.message)
        queryClient.invalidateQueries({ queryKey: ['odps'] })
        handleClose()
      } else {
        toast.error(data.error || 'Gagal memperbarui data')
      }
    },
    onError: (error: any) => {
      toast.error(error.response?.data?.error || 'Terjadi kesalahan sistem')
    },
  })

  const handleClose = () => {
    setUpdateOdc(false)
    setOdcAction('move')
    setTargetOdcId('')
    setUpdateParent(false)
    setParentAction('move')
    setTargetParentId('')
    setUpdateTipeKapasitas(false)
    setType('splitter')
    setSplitterType('1:8')
    setRatioUsed(50)
    setRatioTotal(50)
    setUpdateGpon(false)
    setUpdateRx(false)
    setRxPower('')
    onClose()
  }

  const handleSave = () => {
    const hasUpdate = updateTipeKapasitas || updateOdc || updateGpon || updateRx || updateParent
    if (!hasUpdate) {
      toast.warning('Pilih minimal satu bidang untuk diperbarui')
      return
    }
    if (updateOdc && odcAction === 'move' && !targetOdcId) {
      toast.warning('Pilih ODC tujuan terlebih dahulu')
      return
    }
    if (updateParent && parentAction === 'move' && !targetParentId) {
      toast.warning('Pilih Sumber Terusan (ODP) terlebih dahulu')
      return
    }
    mutation.mutate()
  }

  return (
    <Dialog open={isOpen} onOpenChange={(v) => !v && handleClose()}>
      <DialogContent className="max-w-sm rounded-2xl p-0 overflow-hidden border-none shadow-2xl">
        {/* Header */}
        <DialogHeader className="px-5 pt-5 pb-4 bg-gradient-to-r from-blue-500/10 to-transparent border-b">
          <DialogTitle className="text-sm font-black uppercase tracking-wider text-blue-600 dark:text-blue-400 flex items-center gap-2">
            <Settings2 className="h-4 w-4" />
            Edit Masal ODP
            <span className="text-xs bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 px-2 py-0.5 rounded-full font-bold">
              {selectedIds.length} ODP
            </span>
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-3 p-5">
          <p className="text-xs text-muted-foreground">
            Centang kolom yang ingin diubah untuk semua ODP terpilih:
          </p>

          {/* === ODC === */}
          <div className="flex flex-col gap-2 p-3 border rounded-xl bg-muted/20">
            <div className="flex items-center gap-2">
              <Checkbox
                id="upd-odc"
                checked={updateOdc}
                disabled={updateParent}
                onCheckedChange={(v) => setUpdateOdc(!!v)}
              />
              <Label htmlFor="upd-odc" className="text-xs font-bold flex items-center gap-1">
                <Building2 className="h-3.5 w-3.5 text-amber-500" />
                ODC Sumber (Jalur Utama)
              </Label>
            </div>
            {updateOdc && (
              <div className="space-y-2 pl-6 mt-1">
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => setOdcAction('move')}
                    className={`flex-1 text-xs py-1 px-3 rounded-md border font-semibold transition-all ${
                      odcAction === 'move'
                        ? 'bg-blue-500 text-white border-blue-500'
                        : 'bg-background hover:bg-muted/50'
                    }`}
                  >
                    Pindah ODC
                  </button>
                  <button
                    type="button"
                    onClick={() => setOdcAction('detach')}
                    className={`flex-1 text-xs py-1 px-3 rounded-md border font-semibold transition-all ${
                      odcAction === 'detach'
                        ? 'bg-orange-500 text-white border-orange-500'
                        : 'bg-background hover:bg-muted/50'
                    }`}
                  >
                    Lepas ODC
                  </button>
                </div>
                {odcAction === 'move' && (
                  <Select value={targetOdcId} onValueChange={setTargetOdcId}>
                    <SelectTrigger className="h-8 text-xs bg-background">
                      <SelectValue placeholder="Pilih ODC..." />
                    </SelectTrigger>
                    <SelectContent>
                      {odcList.map((odc) => (
                        <SelectItem key={odc.id} value={String(odc.id)} className="text-xs">{odc.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </div>
            )}
          </div>

          {/* === Sumber Terusan ODP === */}
          <div className="flex flex-col gap-2 p-3 border rounded-xl bg-muted/20">
            <div className="flex items-center gap-2">
              <Checkbox
                id="upd-parent"
                checked={updateParent}
                disabled={updateOdc}
                onCheckedChange={(v) => setUpdateParent(!!v)}
              />
              <Label htmlFor="upd-parent" className="text-xs font-bold flex items-center gap-1">
                <Share2 className="h-3.5 w-3.5 text-blue-500" />
                Sumber Terusan (Dari ODP Lain)
              </Label>
            </div>
            {updateParent && (
              <div className="space-y-2 pl-6 mt-1">
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => setParentAction('move')}
                    className={`flex-1 text-xs py-1 px-3 rounded-md border font-semibold transition-all ${
                      parentAction === 'move'
                        ? 'bg-blue-500 text-white border-blue-500'
                        : 'bg-background hover:bg-muted/50'
                    }`}
                  >
                    Pindah Sumber
                  </button>
                  <button
                    type="button"
                    onClick={() => setParentAction('detach')}
                    className={`flex-1 text-xs py-1 px-3 rounded-md border font-semibold transition-all ${
                      parentAction === 'detach'
                        ? 'bg-orange-500 text-white border-orange-500'
                        : 'bg-background hover:bg-muted/50'
                    }`}
                  >
                    Lepas Sumber
                  </button>
                </div>
                {parentAction === 'move' && (
                  <Select value={targetParentId} onValueChange={setTargetParentId}>
                    <SelectTrigger className="h-8 text-xs bg-background">
                      <SelectValue placeholder="Pilih ODP Sumber..." />
                    </SelectTrigger>
                    <SelectContent>
                      {odpList.filter(o => !selectedIds.includes(o.id)).map((o) => (
                        <SelectItem key={o.id} value={String(o.id)} className="text-xs">{o.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </div>
            )}
          </div>

          {/* === Tipe ODP & Kapasitas Gabungan === */}
          <div className="flex flex-col gap-2 p-3 border rounded-xl bg-muted/20">
            <div className="flex items-center gap-2">
              <Checkbox
                id="upd-tipe-kapasitas"
                checked={updateTipeKapasitas}
                onCheckedChange={(v) => setUpdateTipeKapasitas(!!v)}
              />
              <Label htmlFor="upd-tipe-kapasitas" className="text-xs font-bold flex items-center gap-1">
                <Layers className="h-3.5 w-3.5 text-purple-500" />
                Tipe & Kapasitas ODP
              </Label>
            </div>
            {updateTipeKapasitas && (
              <div className="pl-6 space-y-3 mt-1">
                <Select value={type} onValueChange={(v) => setType(v as any)} >
                  <SelectTrigger className="h-8 text-xs bg-background">
                    <SelectValue placeholder="Pilih Tipe" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="splitter" className="text-xs">Splitter</SelectItem>
                    <SelectItem value="ratio" className="text-xs">Ratio</SelectItem>
                  </SelectContent>
                </Select>

                {/* Dinamis Input berdasarkan Tipe */}
                {type === 'splitter' ? (
                  <Select value={splitterType} onValueChange={setSplitterType}>
                    <SelectTrigger className="h-8 text-xs bg-background">
                      <SelectValue placeholder="Pilih Kapasitas" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="1:2" className="text-xs">1:2</SelectItem>
                      <SelectItem value="1:4" className="text-xs">1:4</SelectItem>
                      <SelectItem value="1:8" className="text-xs">1:8</SelectItem>
                      <SelectItem value="1:16" className="text-xs">1:16</SelectItem>
                      <SelectItem value="1:32" className="text-xs">1:32</SelectItem>
                    </SelectContent>
                  </Select>
                ) : (
                  <div className="grid grid-cols-2 gap-2">
                    <div className="space-y-1">
                      <Label className="text-[10px] text-muted-foreground font-semibold">TAP (%)</Label>
                      <input
                        type="number"
                        min={0} max={100}
                        value={ratioUsed}
                        onChange={(e) => {
                          const v = parseInt(e.target.value) || 0
                          setRatioUsed(v)
                          setRatioTotal(100 - v)
                        }}
                        className="h-8 w-full rounded-md border border-input bg-background px-3 text-xs"
                      />
                    </div>
                    <div className="space-y-1">
                      <Label className="text-[10px] text-muted-foreground font-semibold">THRU (%)</Label>
                      <input
                        type="number"
                        min={0} max={100}
                        value={ratioTotal}
                        onChange={(e) => {
                          const v = parseInt(e.target.value) || 0
                          setRatioTotal(v)
                          setRatioUsed(100 - v)
                        }}
                        className="h-8 w-full rounded-md border border-input bg-background px-3 text-xs"
                      />
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* === GPON / EPON & Rx Power === */}
          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-2 p-3 border rounded-xl bg-muted/20">
              <div className="flex items-center gap-2">
                <Checkbox id="upd-gpon" checked={updateGpon} onCheckedChange={(v) => setUpdateGpon(!!v)} />
                <Label htmlFor="upd-gpon" className="text-xs font-bold flex items-center gap-1">
                  <Activity className="h-3.5 w-3.5 text-emerald-500" /> GPON/EPON
                </Label>
              </div>
              {updateGpon && (
                <Select value={gponType} onValueChange={setGponType}>
                  <SelectTrigger className="h-8 text-xs bg-background">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="GPON" className="text-xs">GPON</SelectItem>
                    <SelectItem value="EPON" className="text-xs">EPON</SelectItem>
                  </SelectContent>
                </Select>
              )}
            </div>

            <div className="flex flex-col gap-2 p-3 border rounded-xl bg-muted/20">
              <div className="flex items-center gap-2">
                <Checkbox id="upd-rx" checked={updateRx} onCheckedChange={(v) => setUpdateRx(!!v)} />
                <Label htmlFor="upd-rx" className="text-xs font-bold flex items-center gap-1">
                  <Zap className="h-3.5 w-3.5 text-amber-500" /> Rx Sumber
                </Label>
              </div>
              {updateRx && (
                <Input
                  type="text"
                  placeholder="-15.5"
                  value={rxPower}
                  onChange={(e) => setRxPower(e.target.value)}
                  className="h-8 text-xs bg-background"
                />
              )}
            </div>
          </div>
        </div>

        <DialogFooter className="px-5 pb-5 gap-2">
          <Button variant="ghost" size="sm" onClick={handleClose} disabled={mutation.isPending}>
            Batal
          </Button>
          <Button
            size="sm"
            onClick={handleSave}
            disabled={mutation.isPending}
            className="bg-blue-600 hover:bg-blue-700 text-white font-bold"
          >
            {mutation.isPending ? 'Menyimpan...' : `Terapkan ke ${selectedIds.length} ODP`}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
