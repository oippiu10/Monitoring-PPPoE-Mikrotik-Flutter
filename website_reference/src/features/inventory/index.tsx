import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Package, Plus, ArrowDownToLine, ArrowUpFromLine, Trash2, Wallet, Loader2, Search, Pencil, History, Check, ChevronsUpDown } from 'lucide-react'
import { toast } from 'sonner'
import { api } from '@/lib/api'
import { useRouterStore } from '@/stores/router-store'
import { useConfirm } from '@/hooks/use-confirm'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { RouterSelector } from '@/components/router-selector'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { ThemeSwitch } from '@/components/theme-switch'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { cn } from '@/lib/utils'

const fmt = (n: number) => new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(n)

const getBadgeVariant = (category: string) => {
  const cat = category.toLowerCase();
  if (cat.includes('cpe') || cat.includes('inti')) return 'bg-indigo-500/10 text-indigo-700 dark:text-indigo-400 ring-1 ring-indigo-500/20';
  if (cat.includes('kabel')) return 'bg-orange-500/10 text-orange-700 dark:text-orange-400 ring-1 ring-orange-500/20';
  if (cat.includes('distribusi') || cat.includes('pasif')) return 'bg-blue-500/10 text-blue-700 dark:text-blue-400 ring-1 ring-blue-500/20';
  if (cat.includes('tiang') || cat.includes('alat')) return 'bg-slate-500/10 text-slate-700 dark:text-slate-400 ring-1 ring-slate-500/20';
  return 'bg-muted text-muted-foreground ring-1 ring-border';
}

const INVENTORY_CATEGORIES = [
  { value: 'Perangkat CPE (ONT/Router)', defaultUnit: 'pcs' },
  { value: 'Perangkat Inti (OLT/Switch)', defaultUnit: 'pcs' },
  { value: 'SFP / Modul Optik', defaultUnit: 'pcs' },
  { value: 'Kabel Drop Core', defaultUnit: 'Roll' },
  { value: 'Kabel Backbone/Feeder', defaultUnit: 'Hasper' },
  { value: 'Kabel UTP/LAN', defaultUnit: 'Box' },
  { value: 'Distribusi (ODP/ODC/FAT)', defaultUnit: 'pcs' },
  { value: 'Pasif Optik (Splitter/Patchcord)', defaultUnit: 'pcs' },
  { value: 'Konektor (FastCon/Sleeve)', defaultUnit: 'pack' },
  { value: 'Aksesoris Tiang (Klem/Bracket)', defaultUnit: 'pcs' },
  { value: 'Tiang (Besi/Beton)', defaultUnit: 'batang' },
  { value: 'Alat Kerja (Splicing/Ukur)', defaultUnit: 'set' },
  { value: 'Lainnya', defaultUnit: 'pcs' },
];

const UNITS = ['pcs', 'unit', 'Roll', 'Meter', 'Kilometer', 'Hasper', 'Box', 'pack', 'batang', 'set', 'klem', 'core', 'pasang', 'lot'];

export function InventoryPage() {
  const { activeRouter } = useRouterStore()
  const queryClient = useQueryClient()
  const [openAdd, setOpenAdd] = useState(false)
  const [movement, setMovement] = useState<any>(null)
  const [form, setForm] = useState({ name: '', category: INVENTORY_CATEGORIES[0].value, stock: '0', unit: INVENTORY_CATEGORIES[0].defaultUnit, price: '0', description: '' })
  const [qty, setQty] = useState('1')
  const [note, setNote] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const [categoryFilter, setCategoryFilter] = useState('Semua')
  const [editingId, setEditingId] = useState<number | null>(null)
  const [historyItem, setHistoryItem] = useState<any>(null)
  const [openCat, setOpenCat] = useState(false)
  const [openUnit, setOpenUnit] = useState(false)

  const { confirm: confirmAction, ConfirmDialog } = useConfirm()

  const routerId = activeRouter?.software_id || activeRouter?.id
  const { data, isLoading } = useQuery({
    queryKey: ['inventory', routerId],
    queryFn: async () => (await api.get('/inventory_operations.php', { params: { action: 'list', router_id: routerId } })).data,
    enabled: !!routerId,
  })

  const addItem = useMutation({
    mutationFn: async () => (await api.post(`/inventory_operations.php?action=add&router_id=${routerId}`, form)).data,
    onSuccess: (d) => { 
      if (d.success) {
        toast.success('Item berhasil ditambahkan')
        setOpenAdd(false)
        setForm({ name: '', category: INVENTORY_CATEGORIES[0].value, stock: '0', unit: INVENTORY_CATEGORIES[0].defaultUnit, price: '0', description: '' })
        queryClient.invalidateQueries({ queryKey: ['inventory'] })
      } else {
        toast.error(d.message || 'Gagal menambahkan item')
      }
    },
  })

  const editItem = useMutation({
    mutationFn: async () => (await api.post(`/inventory_operations.php?action=edit&router_id=${routerId}`, { ...form, id: editingId })).data,
    onSuccess: (d) => {
      if (d.success) {
        toast.success('Item berhasil diperbarui')
        setOpenAdd(false)
        setEditingId(null)
        setForm({ name: '', category: INVENTORY_CATEGORIES[0].value, stock: '0', unit: INVENTORY_CATEGORIES[0].defaultUnit, price: '0', description: '' })
        queryClient.invalidateQueries({ queryKey: ['inventory'] })
      } else {
        toast.error(d.message || 'Gagal memperbarui item')
      }
    },
  })

  const { data: historyData, isLoading: historyLoading } = useQuery({
    queryKey: ['inventory_history', routerId, historyItem?.id],
    queryFn: async () => (await api.get('/inventory_operations.php', { params: { action: 'log', router_id: routerId, inventory_id: historyItem?.id } })).data,
    enabled: !!historyItem?.id,
  })

  const moveItem = useMutation({
    mutationFn: async () => (await api.post(`/inventory_operations.php?action=movement&router_id=${routerId}`, { 
      id: movement?.id, 
      type: movement?.type, 
      qty: Number(qty), 
      note: note || 'Mutasi dari dashboard' 
    })).data,
    onSuccess: (d) => { 
      if (d.success) {
        toast.success('Mutasi stok berhasil disimpan')
        setMovement(null)
        queryClient.invalidateQueries({ queryKey: ['inventory'] })
      } else {
        toast.error(d.message || 'Gagal menyimpan mutasi')
      }
    },
  })

  const deleteItem = useMutation({
    mutationFn: async (id: number) => (await api.post(`/inventory_operations.php?action=delete&router_id=${routerId}`, { id })).data,
    onSuccess: (d) => { 
      if (d.success) {
        toast.success('Item berhasil dihapus')
        queryClient.invalidateQueries({ queryKey: ['inventory'] })
      } else {
        toast.error(d.message || 'Gagal menghapus item')
      }
    },
  })

  const items = data?.data || []
  const summary = data?.summary || { total_items: 0, total_value: 0, low_stock: 0 }

  const filteredItems = items.filter((item: any) => {
    const matchSearch = item.name.toLowerCase().includes(searchQuery.toLowerCase()) || (item.description || '').toLowerCase().includes(searchQuery.toLowerCase())
    const matchCategory = categoryFilter === 'Semua' || item.category === categoryFilter
    return matchSearch && matchCategory
  })

  return (
    <>
      <Header fixed>
        <div className='me-auto flex items-center gap-2'>
          <div className='rounded-lg bg-primary/10 p-2'>
            <Package className='h-5 w-5 text-primary' />
          </div>
          <h1 className='text-lg font-bold'>Inventory & Asset</h1>
        </div>
        <RouterSelector />
        <ThemeSwitch />
        <ProfileDropdown />
      </Header>
      
      <Main className='space-y-4' fluid>
        <div className='flex flex-col sm:flex-row sm:items-center justify-between gap-4'>
          <div className="space-y-1">
            <h2 className='text-3xl font-black tracking-tight bg-linear-to-br from-foreground to-foreground/70 bg-clip-text text-transparent'>Inventory & Asset</h2>
            <p className='text-muted-foreground text-sm font-medium'>Kelola stok perangkat, material fiber, dan asset jaringan Anda.</p>
          </div>
          <Button onClick={() => { setEditingId(null); setForm({ name: '', category: INVENTORY_CATEGORIES[0].value, stock: '0', unit: INVENTORY_CATEGORIES[0].defaultUnit, price: '0', description: '' }); setOpenAdd(true) }} className='shadow-lg shadow-primary/20 hover:shadow-primary/30 transition-all rounded-xl'>
            <Plus className='mr-2 h-4 w-4' /> Tambah Item Baru
          </Button>
        </div>

        <div className='grid gap-3 md:grid-cols-3'>
          <Card className='border border-blue-500/15 shadow-md shadow-blue-500/5 bg-linear-to-br from-blue-500/5 via-transparent to-transparent backdrop-blur-xs rounded-xl'>
            <CardContent className='flex items-center gap-3 p-4'>
              <div className='p-2 bg-blue-500/10 rounded-lg text-blue-600 dark:text-blue-400 ring-1 ring-blue-500/20 shadow-inner'>
                <Package className='h-5 w-5' />
              </div>
              <div>
                <p className='text-[10px] font-bold uppercase tracking-wider text-muted-foreground/80'>Total Jenis</p>
                <p className='text-xl font-black tracking-tight'>{summary.total_items}</p>
              </div>
            </CardContent>
          </Card>
          
          <Card className='border border-emerald-500/15 shadow-md shadow-emerald-500/5 bg-linear-to-br from-emerald-500/5 via-transparent to-transparent backdrop-blur-xs rounded-xl'>
            <CardContent className='flex items-center gap-3 p-4'>
              <div className='p-2 bg-emerald-500/10 rounded-lg text-emerald-600 dark:text-emerald-400 ring-1 ring-emerald-500/20 shadow-inner'>
                <Wallet className='h-5 w-5' />
              </div>
              <div>
                <p className='text-[10px] font-bold uppercase tracking-wider text-muted-foreground/80'>Total Nilai Asset</p>
                <p className='text-xl font-black tracking-tight text-emerald-600 dark:text-emerald-400'>{fmt(summary.total_value)}</p>
              </div>
            </CardContent>
          </Card>
          
          <Card className='border border-orange-500/15 shadow-md shadow-orange-500/5 bg-linear-to-br from-orange-500/5 via-transparent to-transparent backdrop-blur-xs rounded-xl'>
            <CardContent className='flex items-center gap-3 p-4'>
              <div className='p-2 bg-orange-500/10 rounded-lg text-orange-600 dark:text-orange-400 ring-1 ring-orange-500/20 shadow-inner'>
                <Package className='h-5 w-5' />
              </div>
              <div>
                <p className='text-[10px] font-bold uppercase tracking-wider text-muted-foreground/80'>Stok Menipis</p>
                <p className='text-xl font-black tracking-tight text-orange-600 dark:text-orange-400'>{summary.low_stock}</p>
              </div>
            </CardContent>
          </Card>
        </div>

        <Card className='overflow-hidden border border-border/40 shadow-xl rounded-2xl bg-card/50 backdrop-blur-sm'>
          {/* Action Bar: Search & Filter */}
          <div className="px-5 py-4 border-b border-border/40 flex flex-col sm:flex-row sm:items-center gap-4 bg-card/80">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground/60" />
              <Input 
                placeholder="Cari nama barang atau deskripsi..." 
                className="pl-9 h-9 rounded-lg bg-muted/40 border-transparent shadow-none focus-visible:ring-primary/20 focus-visible:bg-background transition-all" 
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
              />
            </div>
            <Select value={categoryFilter} onValueChange={setCategoryFilter}>
              <SelectTrigger className="w-full sm:w-[200px] h-9 rounded-lg bg-muted/40 border-transparent shadow-none hover:bg-muted/60 transition-all">
                <SelectValue placeholder="Kategori" />
              </SelectTrigger>
              <SelectContent className="rounded-xl">
                <SelectItem value="Semua">Semua Kategori</SelectItem>
                {INVENTORY_CATEGORIES.map(c => (
                  <SelectItem key={c.value} value={c.value}>{c.value}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className='overflow-x-auto w-full'>
            <Table>
              <TableHeader className='bg-transparent border-b border-border/40'>
                <TableRow className="hover:bg-transparent">
                  <TableHead className='font-bold text-[10px] tracking-wider uppercase text-muted-foreground h-10 pl-5'>Nama Barang / Deskripsi</TableHead>
                  <TableHead className='font-bold text-[10px] tracking-wider uppercase text-muted-foreground h-10'>Kategori</TableHead>
                  <TableHead className='text-right font-bold text-[10px] tracking-wider uppercase text-muted-foreground h-10'>Sisa Stok</TableHead>
                  <TableHead className='text-right font-bold text-[10px] tracking-wider uppercase text-muted-foreground h-10'>Harga Satuan</TableHead>
                  <TableHead className='text-right font-bold text-[10px] tracking-wider uppercase text-muted-foreground h-10'>Total Nilai</TableHead>
                  <TableHead className='text-right font-bold text-[10px] tracking-wider uppercase text-muted-foreground h-10 w-32 pr-5'>Aksi</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {isLoading ? (
                  <TableRow>
                    <TableCell colSpan={6} className='py-12 text-center text-muted-foreground'>
                      <Loader2 className="w-6 h-6 animate-spin mx-auto text-primary" />
                    </TableCell>
                  </TableRow>
                ) : filteredItems.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} className='py-16 text-center text-muted-foreground font-medium'>
                      <div className="flex flex-col items-center justify-center gap-2">
                        <Package className="h-8 w-8 text-muted-foreground/30" />
                        {searchQuery ? 'Tidak ada barang yang cocok dengan pencarian' : 'Belum ada data inventory untuk router ini'}
                      </div>
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredItems.map((item: any) => (
                    <TableRow key={item.id} className='hover:bg-muted/40 transition-colors group'>
                      <TableCell className='font-bold text-sm pl-5'>
                        {item.name}
                        {item.description && (
                          <p className='text-xs font-medium text-muted-foreground mt-1'>{item.description}</p>
                        )}
                      </TableCell>
                      <TableCell>
                        <Badge variant='outline' className={cn('rounded-lg font-bold text-[10px] uppercase border-transparent', getBadgeVariant(item.category))}>
                          {item.category}
                        </Badge>
                      </TableCell>
                      <TableCell className='text-right font-mono font-bold text-sm'>
                        <span className={item.stock <= 3 ? 'text-red-500 font-black' : ''}>
                          {item.stock}
                        </span>{' '}
                        <span className='text-xs font-normal text-muted-foreground'>{item.unit || 'pcs'}</span>
                      </TableCell>
                      <TableCell className='text-right font-mono text-sm'>{fmt(Number(item.price))}</TableCell>
                      <TableCell className='text-right font-mono font-bold text-sm text-primary'>{fmt(Number(item.asset_value))}</TableCell>
                      <TableCell className='text-right pr-5'>
                        <div className='flex justify-end gap-1.5'>
                          <Button 
                            size='icon' 
                            variant='ghost' 
                            className='h-8 w-8 bg-green-500/10 text-green-600 hover:bg-green-500/20 hover:text-green-700 dark:bg-green-500/10 dark:text-green-400 dark:hover:bg-green-500/20' 
                            title='Stok Masuk'
                            onClick={() => { setQty('1'); setNote(''); setMovement({ ...item, type: 'in' }) }}
                          >
                            <ArrowDownToLine className='h-4 w-4' />
                          </Button>
                          <Button 
                            size='icon' 
                            variant='ghost' 
                            className='h-8 w-8 bg-orange-500/10 text-orange-600 hover:bg-orange-500/20 hover:text-orange-700 dark:bg-orange-500/10 dark:text-orange-400 dark:hover:bg-orange-500/20' 
                            title='Stok Keluar'
                            onClick={() => { setQty('1'); setNote(''); setMovement({ ...item, type: 'out' }) }}
                          >
                            <ArrowUpFromLine className='h-4 w-4' />
                          </Button>
                          <Button 
                            size='icon' 
                            variant='ghost' 
                            className='h-8 w-8 hover:bg-indigo-50 dark:hover:bg-indigo-950/20 text-indigo-500' 
                            title='Riwayat Mutasi'
                            onClick={() => setHistoryItem(item)}
                          >
                            <History className='h-4 w-4' />
                          </Button>
                          <Button 
                            size='icon' 
                            variant='ghost' 
                            className='h-8 w-8 hover:bg-slate-100 dark:hover:bg-slate-800' 
                            title='Edit Barang'
                            onClick={() => {
                              setForm({ name: item.name, category: item.category, stock: item.stock, unit: item.unit, price: item.price, description: item.description })
                              setEditingId(item.id)
                              setOpenAdd(true)
                            }}
                          >
                            <Pencil className='h-4 w-4' />
                          </Button>
                          <Button 
                            size='icon' 
                            variant='ghost' 
                            className='h-8 w-8 text-red-500 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-950/35' 
                            title='Hapus Barang'
                            onClick={async () => {
                              const ok = await confirmAction({
                                title: 'Hapus Item',
                                description: `Apakah Anda yakin ingin menghapus item "${item.name}" dari inventori?`,
                                confirmText: 'Hapus',
                                cancelText: 'Batal',
                                variant: 'destructive'
                              })
                              if (ok) deleteItem.mutate(Number(item.id))
                            }}
                          >
                            <Trash2 className='h-4 w-4' />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </Card>
      </Main>

      <Dialog open={openAdd} onOpenChange={setOpenAdd}>
        <DialogContent className='max-w-md rounded-xl'>
          <DialogHeader>
            <DialogTitle className='flex items-center gap-2 text-primary font-bold'>
              {editingId ? <Pencil className='h-5 w-5' /> : <Package className='h-5 w-5' />}
              {editingId ? 'Edit Inventory' : 'Tambah Inventory'}
            </DialogTitle>
          </DialogHeader>
          <div className='grid gap-4 py-2'>
            <div className='grid gap-1.5'>
              <Label className='text-xs font-semibold'>Nama Barang</Label>
              <Input placeholder='Nama barang' value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className='rounded-lg' />
            </div>
            
            <div className='grid gap-1.5'>
              <Label className='text-xs font-semibold'>Kategori</Label>
              <Popover open={openCat} onOpenChange={setOpenCat}>
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    role="combobox"
                    aria-expanded={openCat}
                    className="w-full justify-between rounded-lg font-normal"
                  >
                    {form.category || "Pilih Kategori..."}
                    <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-[400px] p-0 rounded-lg">
                  <Command>
                    <CommandInput placeholder="Cari kategori..." className="h-9" />
                    <CommandList>
                      <CommandEmpty>Kategori tidak ditemukan.</CommandEmpty>
                      <CommandGroup>
                        {INVENTORY_CATEGORIES.map((c) => (
                          <CommandItem
                            key={c.value}
                            value={c.value}
                            onSelect={(currentValue) => {
                              const actualCategory = INVENTORY_CATEGORIES.find(cat => cat.value.toLowerCase() === currentValue.toLowerCase())
                              if (actualCategory) {
                                setForm({ ...form, category: actualCategory.value, unit: actualCategory.defaultUnit || 'pcs' })
                              } else {
                                setForm({ ...form, category: currentValue })
                              }
                              setOpenCat(false)
                            }}
                          >
                            {c.value}
                            <Check
                              className={cn(
                                "ml-auto h-4 w-4",
                                form.category === c.value ? "opacity-100" : "opacity-0"
                              )}
                            />
                          </CommandItem>
                        ))}
                      </CommandGroup>
                    </CommandList>
                  </Command>
                </PopoverContent>
              </Popover>
            </div>

            <div className='grid grid-cols-3 gap-3'>
              <div className='grid gap-1.5'>
                <Label className='text-xs font-semibold'>{editingId ? 'Stok (Ubah via Mutasi)' : 'Stok Awal'}</Label>
                <Input type='number' placeholder='Stok' value={form.stock} onChange={(e) => setForm({ ...form, stock: e.target.value })} className='rounded-lg' disabled={!!editingId} />
              </div>
              <div className='grid gap-1.5'>
                <Label className='text-xs font-semibold'>Satuan</Label>
                <Popover open={openUnit} onOpenChange={setOpenUnit}>
                  <PopoverTrigger asChild>
                    <Button
                      variant="outline"
                      role="combobox"
                      aria-expanded={openUnit}
                      className="w-full justify-between rounded-lg font-normal px-3"
                    >
                      {form.unit || "Satuan"}
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-[200px] p-0 rounded-lg" align="start">
                    <Command>
                      <CommandInput placeholder="Cari satuan..." className="h-9" />
                      <CommandList>
                        <CommandEmpty>
                          Satuan tidak ditemukan.
                        </CommandEmpty>
                        <CommandGroup>
                          {UNITS.map((u) => (
                            <CommandItem
                              key={u}
                              value={u}
                              onSelect={(currentValue) => {
                                const actualUnit = UNITS.find(unit => unit.toLowerCase() === currentValue.toLowerCase()) || currentValue
                                setForm({ ...form, unit: actualUnit })
                                setOpenUnit(false)
                              }}
                            >
                              {u}
                              <Check
                                className={cn(
                                  "ml-auto h-4 w-4",
                                  form.unit === u ? "opacity-100" : "opacity-0"
                                )}
                              />
                            </CommandItem>
                          ))}
                        </CommandGroup>
                      </CommandList>
                    </Command>
                  </PopoverContent>
                </Popover>
              </div>
              <div className='grid gap-1.5'>
                <Label className='text-xs font-semibold'>Harga Satuan</Label>
                <Input type='number' placeholder='Harga' value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} className='rounded-lg' />
              </div>
            </div>

            <div className='grid gap-1.5'>
              <Label className='text-xs font-semibold'>Deskripsi</Label>
              <Input placeholder='Deskripsi singkat' value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} className='rounded-lg' />
            </div>
          </div>
          <DialogFooter className='gap-2 sm:gap-0 mt-2'>
            <Button variant='outline' onClick={() => setOpenAdd(false)} className='rounded-lg'>Batal</Button>
            <Button onClick={() => editingId ? editItem.mutate() : addItem.mutate()} disabled={addItem.isPending || editItem.isPending} className='rounded-lg'>
              {(addItem.isPending || editItem.isPending) ? <Loader2 className="w-4 h-4 animate-spin" /> : 'Simpan'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={!!movement} onOpenChange={() => setMovement(null)}>
        <DialogContent className='max-w-sm rounded-xl'>
          <DialogHeader>
            <DialogTitle className='flex items-center gap-2 text-primary font-bold'>
              {movement?.type === 'in' ? (
                <ArrowDownToLine className='h-5 w-5 text-green-500' />
              ) : (
                <ArrowUpFromLine className='h-5 w-5 text-orange-500' />
              )}
              {movement?.type === 'in' ? 'Mutasi Stok Masuk' : 'Mutasi Stok Keluar'}
            </DialogTitle>
          </DialogHeader>
          <div className='grid gap-4 py-2'>
            <div className='text-sm font-semibold text-muted-foreground'>
              Nama Barang: <span className='text-foreground font-bold'>{movement?.name}</span>
            </div>
            
            <div className='grid gap-1.5'>
              <Label className='text-xs font-semibold'>Jumlah Mutasi ({movement?.unit || 'pcs'})</Label>
              <Input type='number' min='1' value={qty} onChange={(e) => setQty(e.target.value)} className='rounded-lg font-mono font-bold' />
            </div>

            <div className='grid gap-1.5'>
              <Label className='text-xs font-semibold'>Catatan Mutasi</Label>
              <Input placeholder='Keterangan mutasi stok' value={note} onChange={(e) => setNote(e.target.value)} className='rounded-lg' />
            </div>
          </div>
          <DialogFooter className='gap-2 sm:gap-0 mt-2'>
            <Button variant='outline' onClick={() => setMovement(null)} className='rounded-lg'>Batal</Button>
            <Button onClick={() => moveItem.mutate()} disabled={moveItem.isPending} className='rounded-lg'>
              {moveItem.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : 'Simpan Mutasi'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      
      <ConfirmDialog />

      <Dialog open={!!historyItem} onOpenChange={() => setHistoryItem(null)}>
        <DialogContent className='max-w-md rounded-xl'>
          <DialogHeader>
            <DialogTitle className='flex items-center gap-2 text-primary font-bold'>
              <History className='h-5 w-5' />
              Riwayat Mutasi
            </DialogTitle>
          </DialogHeader>
          <div className='text-sm font-semibold text-muted-foreground mb-2'>
            Barang: <span className='text-foreground font-bold'>{historyItem?.name}</span>
          </div>
          <div className="max-h-[300px] overflow-y-auto space-y-3 pr-2">
             {historyLoading ? (
               <div className="flex justify-center py-4"><Loader2 className="h-5 w-5 animate-spin text-primary" /></div>
             ) : historyData?.data?.length === 0 ? (
               <div className="text-center py-8 text-muted-foreground text-sm flex flex-col items-center">
                 <History className="h-8 w-8 mb-2 opacity-20" />
                 Belum ada riwayat pergerakan
               </div>
             ) : (
               historyData?.data?.map((log: any) => (
                 <div key={log.id} className="border rounded-lg p-3 flex justify-between items-start bg-muted/10 hover:bg-muted/30 transition-colors">
                   <div className="space-y-1.5">
                     <div className="flex items-center gap-2">
                       {log.type === 'in' ? <Badge className="bg-green-500/10 text-green-600 hover:bg-green-500/20 text-[10px] px-1.5 border-green-200/50">Masuk</Badge> : 
                        log.type === 'out' ? <Badge className="bg-orange-500/10 text-orange-600 hover:bg-orange-500/20 text-[10px] px-1.5 border-orange-200/50">Keluar</Badge> : 
                        <Badge variant="outline" className="text-[10px] px-1.5">Penyesuaian</Badge>}
                       <span className="font-bold text-sm">
                         {log.type === 'in' ? '+' : log.type === 'out' ? '-' : ''}{log.qty} {historyItem?.unit}
                       </span>
                     </div>
                     <p className="text-xs text-foreground font-medium">{log.note || '-'}</p>
                     <p className="text-[10px] text-muted-foreground">Oleh: {log.admin_name || 'Sistem'}</p>
                   </div>
                   <div className="text-[10px] font-medium text-muted-foreground opacity-70 text-right">
                     {new Date(log.created_at).toLocaleString('id-ID', { dateStyle: 'short', timeStyle: 'short' })}
                   </div>
                 </div>
               ))
             )}
          </div>
        </DialogContent>
      </Dialog>
    </>
  )
}
