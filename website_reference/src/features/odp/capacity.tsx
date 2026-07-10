import { useState, useMemo, useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { api } from '@/lib/api'
import { useRouterStore } from '@/stores/router-store'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { ThemeSwitch } from '@/components/theme-switch'
import { RouterSelector } from '@/components/router-selector'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { ODPSubNav } from './components/odp-sub-nav'
import { Server, Share2, Users, PieChart, TrendingUp, AlertTriangle, ShieldCheck, Search, ChevronLeft, ChevronRight, ArrowUpDown, ChevronsLeft, ChevronsRight } from 'lucide-react'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Button } from '@/components/ui/button'
import { usePPPoEData } from '../pppoe/hooks/use-pppoe-data'
import { cn, getPageNumbers } from '@/lib/utils'

import { PieChart as RePieChart, Pie, Cell, ResponsiveContainer, Tooltip as ReTooltip, Legend } from 'recharts'

import { ODPDetailDialog } from './components/odp-detail-dialog'
import { ODCDetailDialog } from '../odc/components/odc-detail-dialog'

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6']

export function ODPCapacity() {
  const { activeRouter } = useRouterStore()
  const navigate = useNavigate()
  const { pppSecrets } = usePPPoEData()

  // State for search, sort, pagination
  const [searchTerm, setSearchTerm] = useState('')
  const [sortBy, setSortBy] = useState<'name' | 'usage' | 'capacity'>('name')
  const [currentPage, setCurrentPage] = useState(1)
  const [itemsPerPage, setItemsPerPage] = useState(5)
  const [isMounted, setIsMounted] = useState(false)

  // Dialog states
  const [selectedODP, setSelectedODP] = useState<any>(null)
  const [selectedODC, setSelectedODC] = useState<any>(null)

  useEffect(() => {
    setIsMounted(true)
  }, [])

  const { data: odpList, isLoading: odpLoading } = useQuery({
    queryKey: ['odps', activeRouter?.id],
    queryFn: async () => {
      if (!activeRouter) return []
      const res = await api.get('/odp.php', {
        params: { router_id: activeRouter.id },
      })
      return res.data.data || []
    },
    enabled: !!activeRouter,
  })

  const { data: odcList, isLoading: odcLoading } = useQuery({
    queryKey: ['odcs', activeRouter?.id],
    queryFn: async () => {
      if (!activeRouter) return []
      const res = await api.get('/odc.php', {
        params: { router_id: activeRouter.id },
      })
      return res.data.data || []
    },
    enabled: !!activeRouter,
  })

  const isLoading = odpLoading || odcLoading

  // Calculate Stats
  const totalODC = odcList?.length || 0
  const totalODP = odpList?.length || 0
  const totalSecrets = pppSecrets.length
  
  const totalPorts = useMemo(() => odpList?.reduce((acc: number, odp: any) => {
    if (odp.type === 'splitter') {
      const parts = odp.splitter_type?.split(':')
      const ports = parts && parts.length > 1 ? parseInt(parts[1]) : 0
      return acc + (ports || 0)
    }
    // Jika ratio, fisiknya adalah splitter 1:2 dengan 2 port
    return acc + 2
  }, 0) || 0, [odpList])

  const usedPorts = useMemo(() => odpList?.reduce((acc: number, odp: any) => {
    // Port terpakai berdasarkan jumlah total_users yang terhubung
    return acc + (parseInt(odp.total_users) || 0)
  }, 0) || 0, [odpList])

  const assignedUsersCount = useMemo(() => odpList?.reduce((acc: number, odp: any) => acc + (parseInt(odp.total_users) || 0), 0) || 0, [odpList])
  const unassignedCount = Math.max(0, totalSecrets - assignedUsersCount)

  const freePorts = totalPorts - usedPorts
  const overallUsage = totalPorts > 0 ? Math.round((usedPorts / totalPorts) * 100) : 0

  // Chart Data: Splitter vs Ratio
  const typeData = useMemo(() => {
    if (!odpList) return []
    let splitter = 0, ratio = 0
    odpList.forEach((o: any) => {
        if (o.type === 'splitter') splitter++
        else ratio++
    })
    return [
        { name: 'Splitter', value: splitter },
        { name: 'Ratio', value: ratio }
    ]
  }, [odpList])

  // ODC Usage Data
  const odcUsageData = useMemo(() => {
    if (!odcList || !odpList) return []
    return odcList.map((odc: any) => {
        const connectedODPs = odpList.filter((o: any) => o.odc_id === odc.id).length
        const cap = parseInt(odc.capacity) || 0
        const usage = cap > 0 ? Math.round((connectedODPs / cap) * 100) : 0
        return {
            ...odc,
            used: connectedODPs,
            capacity: cap,
            usage: usage,
            isFull: usage >= 90,
            isNearFull: usage >= 70 && usage < 90
        }
    }).sort((a: any, b: any) => b.usage - a.usage)
  }, [odcList, odpList])

  // Combined Assets Data for Chart
  const assetData = useMemo(() => {
    const odcCount = odcList?.length || 0
    let odpSplitter = 0
    let odpRatio = 0
    odpList?.forEach((o: any) => {
        if (o.type === 'splitter') odpSplitter++
        else odpRatio++
    })
    return [
        { name: 'ODC', value: odcCount, color: '#f59e0b' }, // amber-500
        { name: 'ODP Splitter', value: odpSplitter, color: '#3b82f6' }, // blue-500
        { name: 'ODP Ratio', value: odpRatio, color: '#8b5cf6' } // violet-500
    ].filter(d => d.value > 0)
  }, [odcList, odpList])

  const totalODCPorts = useMemo(() => {
    let total = 0
    odcUsageData.forEach((odc: any) => total += odc.capacity)
    return total
  }, [odcUsageData])

  const { odcUsed, odcUsagePercentage } = useMemo(() => {
    let used = 0
    odcUsageData.forEach((o: any) => used += o.used)
    const pct = totalODCPorts > 0 ? Math.round((used / totalODCPorts) * 100) : 0
    return { odcUsed: used, odcUsagePercentage: pct }
  }, [odcUsageData, totalODCPorts])

  // Filter and Sort Data
  const filteredAndSortedODP = useMemo(() => {
    if (!odpList) return []
    
    const result = [...odpList].filter(odp => 
      odp.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      odp.location?.toLowerCase().includes(searchTerm.toLowerCase())
    )

    result.sort((a, b) => {
      if (sortBy === 'name') return a.name.localeCompare(b.name)
      
      const getUsage = (o: any) => {
        let cap = 2;
        const u = parseInt(o.total_users) || 0
        if (o.type === 'splitter') {
          const p = o.splitter_type?.split(':')
          cap = p && p.length > 1 ? parseInt(p[1]) : 0
        }
        return cap > 0 ? (u / cap) : 0
      }

      const getCap = (o: any) => {
        if (o.type === 'splitter') {
          const p = o.splitter_type?.split(':')
          return p && p.length > 1 ? parseInt(p[1]) : 0
        }
        return 2 // Ratio memiliki 2 port
      }

      if (sortBy === 'usage') return getUsage(b) - getUsage(a)
      if (sortBy === 'capacity') return getCap(b) - getCap(a)
      return 0
    })

    return result
  }, [odpList, searchTerm, sortBy])

  // Pagination Logic
  const totalPages = Math.ceil(filteredAndSortedODP.length / itemsPerPage)
  const paginatedODP = filteredAndSortedODP.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  )
  const pageNumbers = getPageNumbers(currentPage, totalPages)

  const stats = [
    {
      label: 'Total ODC',
      value: totalODC,
      icon: Server,
      color: 'from-slate-500 to-slate-700 dark:from-slate-700 dark:to-slate-900',
      desc: 'Kabinet pusat distribusi'
    },
    {
      label: 'Total ODP',
      value: totalODP,
      icon: Share2,
      color: 'from-blue-500 to-indigo-600',
      desc: 'Titik distribusi aktif'
    },
    {
      label: 'Kapasitas (Port)',
      value: totalPorts,
      icon: Users,
      color: 'from-emerald-500 to-teal-600',
      desc: `Terpakai: ${usedPorts} | Sisa: ${freePorts}`
    },
    {
      label: 'Status Jaringan',
      value: `${overallUsage}%`,
      icon: ShieldCheck,
      color: overallUsage >= 80 ? 'from-red-500 to-rose-600' : overallUsage >= 60 ? 'from-amber-500 to-orange-600' : 'from-emerald-500 to-teal-600',
      desc: 'Tingkat okupansi'
    }
  ]

  return (
    <>
      <Header fixed>
        <div className='me-auto flex items-center gap-2'>
          <div className='p-2 bg-primary/10 rounded-lg'>
            <PieChart className='h-5 w-5 text-primary' />
          </div>
          <h1 className='text-lg font-bold'>Overview Infrastruktur</h1>
        </div>
        <RouterSelector />
        <ThemeSwitch />
        <ProfileDropdown />
      </Header>

      <Main className='space-y-6' fluid>
        <ODPSubNav active='/odp/capacity' />

        {/* KPI Cards */}
        <div className='grid gap-4 md:grid-cols-2 lg:grid-cols-4'>
          {stats.map((item) => (
            <Card key={item.label} className={cn(
              "relative overflow-hidden border-none shadow-xl bg-gradient-to-br text-white transition-all duration-500",
              item.color,
              isMounted ? "translate-y-0 opacity-100" : "translate-y-4 opacity-0"
            )}>
              <div className='absolute top-0 right-0 p-3 opacity-10'>
                <item.icon className='h-16 w-16' />
              </div>
              <CardHeader className='pb-1'>
                <CardTitle className='text-[10px] font-black uppercase tracking-widest opacity-80'>{item.label}</CardTitle>
              </CardHeader>
              <CardContent>
                <div className='text-4xl font-black mb-1'>
                  {isLoading ? <span className='animate-pulse'>...</span> : item.value}
                </div>
                <p className='text-[10px] font-bold opacity-70 uppercase tracking-wider'>{item.desc}</p>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Unassigned Users Alert */}
        {unassignedCount > 0 && (
            <div className='flex items-center justify-between px-4 py-2 bg-amber-50 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-800 rounded-lg shadow-sm animate-in fade-in slide-in-from-top-2 duration-500'>
                <div className='flex items-center gap-2'>
                    <AlertTriangle className='h-4 w-4 text-amber-600 dark:text-amber-400' />
                    <span className='text-[11px] font-bold text-amber-800 dark:text-amber-200 uppercase tracking-wider'>
                        Perhatian: <span className="text-amber-600 dark:text-amber-400 mx-1">{unassignedCount} User</span> 
                        di router belum dipetakan ke ODP manapun.
                    </span>
                </div>
                <div className="flex items-center gap-3">
                    <Button 
                        size="sm" 
                        className="h-6 text-[10px] font-bold bg-amber-600 hover:bg-amber-700 text-white shadow-sm"
                        onClick={() => navigate({ to: '/customers', search: { odp: 'none' } as any })}
                    >
                        CEK PELANGGAN
                    </Button>
                </div>
            </div>
        )}

        <div className='grid grid-cols-1 lg:grid-cols-3 gap-6'>
            {/* Chart 1: Combined Infrastructure Assets */}
            <Card className='col-span-1 border-none shadow-lg bg-card/50 backdrop-blur-sm'>
                <CardHeader className="text-center border-b pb-4 mb-4">
                    <CardTitle className='text-sm font-black uppercase tracking-tight'>Komposisi Infrastruktur</CardTitle>
                    <CardDescription className='text-[10px] uppercase font-bold tracking-wider'>ODC vs ODP (Splitter & Ratio)</CardDescription>
                </CardHeader>
                <CardContent className='relative flex justify-center items-center h-[220px]'>
                    {isLoading ? (
                        <div className='animate-pulse w-32 h-32 rounded-full bg-muted' />
                    ) : (
                        <>
                            <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none pb-4">
                                <span className="text-4xl font-black tabular-nums text-primary">{totalODC + totalODP}</span>
                                <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest mt-0.5">Total Perangkat</span>
                            </div>
                            <ResponsiveContainer width="100%" height="100%">
                                <RePieChart>
                                    <Pie
                                        data={assetData}
                                        cx="50%"
                                        cy="50%"
                                        innerRadius={70}
                                        outerRadius={90}
                                        paddingAngle={4}
                                        cornerRadius={8}
                                        dataKey="value"
                                    >
                                        {assetData.map((entry, index) => (
                                            <Cell key={`cell-${index}`} fill={entry.color} />
                                        ))}
                                    </Pie>
                                    <ReTooltip 
                                        contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)', fontSize: '12px', fontWeight: 'bold' }}
                                    />
                                    <Legend wrapperStyle={{ fontSize: '10px', fontWeight: 'bold', paddingTop: '0px' }} />
                                </RePieChart>
                            </ResponsiveContainer>
                        </>
                    )}
                </CardContent>
            </Card>

            {/* Occupancy: Dual Linear Bars Variation */}
            <Card className='col-span-1 lg:col-span-2 border-none shadow-lg bg-card/50 backdrop-blur-sm'>
                <CardHeader className="pb-4 border-b">
                    <CardTitle className='text-sm font-black uppercase tracking-tight'>Ringkasan Okupansi Jaringan</CardTitle>
                    <CardDescription className='text-[10px] uppercase font-bold tracking-wider'>Beban Penggunaan Backbone (ODC) & Distribusi (ODP)</CardDescription>
                </CardHeader>
                <CardContent className='pt-8 space-y-8 h-[220px] flex flex-col justify-center'>
                    {/* Progress ODC (Backbone) */}
                    <div>
                        <div className="flex items-end justify-between text-sm mb-2">
                            <div>
                                <span className="font-black uppercase tracking-widest flex items-center gap-2">
                                    <Server className="h-4 w-4 text-orange-500" />
                                    Backbone (ODC)
                                </span>
                            </div>
                            <span className="font-black text-2xl tabular-nums leading-none text-orange-500">{odcUsagePercentage}%</span>
                        </div>
                        <div className="h-5 w-full bg-secondary rounded-md overflow-hidden relative border border-muted">
                            <div 
                                className="h-full bg-gradient-to-r from-orange-400 to-amber-500 transition-all duration-1000 ease-out" 
                                style={{ width: isMounted ? `${odcUsagePercentage}%` : '0%' }} 
                            />
                        </div>
                        <div className="flex justify-between text-[10px] text-muted-foreground font-bold mt-2 uppercase tracking-widest">
                            <span>{odcUsed} Port Terpakai</span>
                            <span>{totalODCPorts} Total Kapasitas</span>
                        </div>
                    </div>

                    {/* Progress ODP (Distribusi) */}
                    <div>
                        <div className="flex items-end justify-between text-sm mb-2">
                            <div>
                                <span className="font-black uppercase tracking-widest flex items-center gap-2">
                                    <TrendingUp className="h-4 w-4 text-primary" />
                                    Distribusi (ODP)
                                </span>
                            </div>
                            <span className="font-black text-2xl tabular-nums leading-none text-primary">{overallUsage}%</span>
                        </div>
                        <div className="h-5 w-full bg-secondary rounded-md overflow-hidden relative border border-muted">
                            <div 
                                className="h-full bg-gradient-to-r from-blue-500 to-indigo-500 transition-all duration-1000 ease-out" 
                                style={{ width: isMounted ? `${overallUsage}%` : '0%' }} 
                            />
                        </div>
                        <div className="flex justify-between text-[10px] text-muted-foreground font-bold mt-2 uppercase tracking-widest">
                            <span>{usedPorts} Port Terpakai</span>
                            <span>{totalPorts} Total Kapasitas</span>
                        </div>
                    </div>
                </CardContent>
            </Card>
        </div>

        
        {/* Smart Analysis */}
        <Card className='border-none shadow-lg bg-card border text-card-foreground'>
            <CardHeader className="bg-muted/30 border-b">
              <CardTitle className='text-lg font-black uppercase tracking-tight flex items-center gap-2'>
                <AlertTriangle className='h-5 w-5 text-amber-500' />
                Analisis & Rekomendasi Sistem
              </CardTitle>
            </CardHeader>
            <CardContent className='grid md:grid-cols-3 gap-4 pt-6'>
               {/* Analisis ODC */}
               <div className='p-4 rounded-xl bg-muted/50 border'>
                  <h4 className='text-sm font-bold mb-1 flex items-center gap-2 text-orange-600 dark:text-orange-400 uppercase tracking-tight'>
                    Backbone Kritis (ODC)
                  </h4>
                  <p className='text-[10px] text-muted-foreground leading-relaxed mb-3'>ODC dengan beban backbone di atas 80% yang butuh penambahan port/modul secepatnya.</p>
                  <div className='space-y-2'>
                    {odcUsageData.filter((o: any) => o.usage >= 80).slice(0, 3).map((o: any) => (
                      <div key={o.id} className='flex justify-between items-center bg-background border p-2 rounded-lg cursor-pointer hover:bg-muted transition-colors' onClick={() => setSelectedODC(o)}>
                        <div className="flex flex-col">
                            <span className='text-xs font-bold'>{o.name}</span>
                            <span className='text-[9px] text-muted-foreground font-bold'>{o.used}/{o.capacity} Port Terpakai</span>
                        </div>
                        <Badge variant="destructive" className='text-[9px] font-black'>{o.usage}%</Badge>
                      </div>
                    ))}
                    {odcUsageData.filter((o: any) => o.usage >= 80).length === 0 && (
                      <p className='text-[10px] italic text-muted-foreground font-bold'>✅ Semua ODC dalam kondisi aman.</p>
                    )}
                  </div>
               </div>

               {/* Analisis ODP */}
               <div className='p-4 rounded-xl bg-muted/50 border'>
                  <h4 className='text-sm font-bold mb-1 flex items-center gap-2 text-blue-600 dark:text-blue-400 uppercase tracking-tight'>
                    Distribusi Kritis (ODP)
                  </h4>
                  <p className='text-[10px] text-muted-foreground leading-relaxed mb-3'>ODP yang port-nya hampir habis (80%+) dan butuh upgrade splitter atau penambahan ODP baru.</p>
                  <div className='space-y-2'>
                    {odpList?.filter((o: any) => {
                      let cap = 2;
                      const u = parseInt(o.total_users) || 0
                      if (o.type === 'splitter') {
                        const p = o.splitter_type?.split(':')
                        cap = p && p.length > 1 ? parseInt(p[1]) : 0
                      }
                      return cap > 0 && (u / cap) >= 0.8
                    }).slice(0, 3).map((o: any) => (
                      <div key={o.id} className='flex justify-between items-center bg-background border p-2 rounded-lg cursor-pointer hover:bg-muted transition-colors' onClick={() => setSelectedODP(o)}>
                        <div className="flex flex-col">
                            <span className='text-xs font-bold truncate w-32'>{o.name}</span>
                        </div>
                        <Badge variant="destructive" className='text-[9px] font-black'>Penuh</Badge>
                      </div>
                    ))}
                    {odpList?.filter((o: any) => {
                      let cap = 2;
                      const u = parseInt(o.total_users) || 0
                      if (o.type === 'splitter') {
                        const p = o.splitter_type?.split(':')
                        cap = p && p.length > 1 ? parseInt(p[1]) : 0
                      }
                      return cap > 0 && (u / cap) >= 0.8
                    }).length === 0 && (
                      <p className='text-[10px] italic text-muted-foreground font-bold'>✅ Semua ODP masih tersedia port kosong.</p>
                    )}
                  </div>
               </div>

               {/* Rekomendasi Eksekusi */}
               <div className='p-4 rounded-xl bg-primary/5 border border-primary/20'>
                  <h4 className='text-sm font-bold mb-1 flex items-center gap-2 text-primary uppercase tracking-tight'>
                    Rekomendasi Eksekusi
                  </h4>
                  <p className='text-[10px] text-muted-foreground leading-relaxed'>
                    Berdasarkan beban jaringan <b>{overallUsage}%</b> (Distribusi) dan <b>{odcUsagePercentage}%</b> (Backbone), berikut adalah saran eksekusi teknisi:
                  </p>
                  <div className="mt-3 p-3 bg-background rounded-lg border shadow-sm space-y-2">
                    {odcUsagePercentage >= 80 ? (
                        <p className="text-[10px] font-bold text-red-600 dark:text-red-400">🔥 Segera tambah modul PON/Kapasitas ODC karena jalur utama sudah kritis.</p>
                    ) : (
                        <p className="text-[10px] font-bold text-emerald-600 dark:text-emerald-400">✅ Kapasitas Backbone ODC masih sangat mumpuni untuk ekspansi.</p>
                    )}
                    
                    {overallUsage >= 80 ? (
                        <p className="text-[10px] font-bold text-orange-600 dark:text-orange-400">⚠️ Okupansi ODP padat. Lakukan pemecahan jalur (Splitter 1:16) di titik merah.</p>
                    ) : (
                        <p className="text-[10px] font-bold text-blue-600 dark:text-blue-400">💡 Fokuskan pada marketing dan akuisisi pelanggan baru di area ODP kosong.</p>
                    )}
                  </div>
               </div>
            </CardContent>
          </Card>
        
        {/* Vertical Stack: Detailed Data */}
        <div className='space-y-6'>
            {/* ODC Backbone Distribution */}
        <Card className='border-none shadow-lg bg-card/50 backdrop-blur-sm'>
            <CardHeader className="flex flex-row items-center justify-between pb-4 border-b">
                <div>
                    <CardTitle className='text-lg font-black uppercase tracking-tight'>Distribusi Backbone per ODC</CardTitle>
                    <CardDescription className='text-xs'>Okupansi port backbone ODC menuju ODP. Klik untuk detail.</CardDescription>
                </div>
                <Badge variant="outline" className="font-bold border-primary/30 text-primary">
                    {totalODC} ODC Terdaftar
                </Badge>
            </CardHeader>
            <CardContent className="pt-6">
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {odcLoading ? (
                        [1,2,3].map(i => <div key={i} className="h-20 bg-muted animate-pulse rounded-lg" />)
                    ) : odcUsageData.length > 0 ? (
                        odcUsageData.map((odc: any) => (
                            <div 
                                key={odc.id} 
                                onClick={() => setSelectedODC(odc)}
                                className="group p-4 border rounded-xl hover:border-primary/50 hover:bg-muted/30 transition-all cursor-pointer relative overflow-hidden"
                            >
                                <div className="absolute top-0 right-0 p-3 opacity-5">
                                    <Server className="h-12 w-12" />
                                </div>
                                <div className="flex justify-between items-start mb-3">
                                    <div className="z-10">
                                        <h4 className="text-sm font-black group-hover:text-primary transition-colors">{odc.name}</h4>
                                        <p className="text-[10px] text-muted-foreground font-bold uppercase">{odc.location || 'Lokasi Kosong'}</p>
                                    </div>
                                    <Badge variant={odc.isFull ? "destructive" : odc.isNearFull ? "outline" : "secondary"} className={cn("z-10 text-[9px] font-black", odc.isNearFull && "text-orange-500 border-orange-500/50 bg-orange-500/10")}>
                                        {odc.used} / {odc.capacity || '?'} Port
                                    </Badge>
                                </div>
                                <div className="h-1.5 w-full bg-secondary rounded-full overflow-hidden z-10 relative">
                                    <div 
                                        className={cn(
                                            "h-full transition-all duration-1000 ease-out",
                                            odc.isFull ? "bg-red-500" : odc.isNearFull ? "bg-orange-500" : "bg-primary"
                                        )}
                                        style={{ width: isMounted ? `${Math.min(odc.usage, 100)}%` : '0%' }}
                                    />
                                </div>
                            </div>
                        ))
                    ) : (
                        <div className="col-span-full text-center py-6 text-muted-foreground text-sm font-bold italic">
                            Belum ada ODC yang terdaftar.
                        </div>
                    )}
                </div>
            </CardContent>
        </Card>

        
            {/* Detailed List with Professional Pagination */}
          <Card className='border-none shadow-lg bg-card/50 backdrop-blur-sm'>
            <CardHeader className="flex flex-col sm:flex-row sm:items-center justify-between space-y-2 pb-4 border-b mb-4">
              <div>
                <CardTitle className='text-lg font-black uppercase tracking-tight'>Distribusi Port per ODP</CardTitle>
                <CardDescription className='text-xs'>Klik baris ODP untuk melihat spesifikasi detail.</CardDescription>
              </div>
              <div className="flex items-center gap-2">
                 <div className="relative">
                    <Search className="absolute left-2 top-2.5 h-3.5 w-3.5 text-muted-foreground" />
                    <Input 
                        placeholder="Cari ODP..." 
                        className="h-8 pl-8 text-xs w-48 bg-background"
                        value={searchTerm}
                        onChange={(e) => {
                            setSearchTerm(e.target.value)
                            setCurrentPage(1)
                        }}
                    />
                 </div>
                 <Select value={sortBy} onValueChange={(v: any) => setSortBy(v)}>
                    <SelectTrigger className="h-8 text-xs w-32 bg-background">
                        <ArrowUpDown className="mr-2 h-3 w-3" />
                        <SelectValue placeholder="Urutkan" />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="name" className="text-xs">Nama ODP</SelectItem>
                        <SelectItem value="usage" className="text-xs">Penggunaan Tinggi</SelectItem>
                        <SelectItem value="capacity" className="text-xs">Kapasitas Terbesar</SelectItem>
                    </SelectContent>
                 </Select>
              </div>
            </CardHeader>
            <CardContent className='space-y-4 pt-2 pb-2'>
              {isLoading ? (
                <div className='space-y-4'>
                   {[1,2,3].map(i => <div key={i} className='h-12 bg-muted animate-pulse rounded-lg' />)}
                </div>
              ) : (
                paginatedODP.map((odp: any) => {
                  let capacity = 2 // Default 2 port untuk ratio
                  const used = parseInt(odp.total_users) || 0

                  if (odp.type === 'splitter') {
                    const parts = odp.splitter_type?.split(':')
                    capacity = parts && parts.length > 1 ? parseInt(parts[1]) : 0
                  }

                  const usage = capacity > 0 ? Math.round((used / capacity) * 100) : 0
                  const isFull = usage >= 90
                  const isNearFull = usage >= 70 && usage < 90

                  return (
                    <div 
                      key={odp.id} 
                      onClick={() => setSelectedODP(odp)}
                      className='group border p-3 rounded-lg hover:border-primary/50 hover:bg-muted/30 transition-all cursor-pointer'
                    >
                      <div className='flex justify-between items-end mb-2'>
                        <div className='flex flex-col'>
                          <span className='text-sm font-black group-hover:text-primary transition-colors'>{odp.name}</span>
                          <span className='text-[10px] text-muted-foreground font-bold uppercase'>{odp.location || 'Lokasi Belum Diatur'}</span>
                        </div>
                        <div className='flex flex-col items-end'>
                           <div className='flex items-center gap-2'>
                              {isFull && <AlertTriangle className='h-3 w-3 text-red-500 animate-pulse' />}
                              <span className={cn(
                                'text-xs font-black',
                                isFull ? 'text-red-500' : isNearFull ? 'text-orange-500' : 'text-primary'
                              )}>
                                {odp.type === 'ratio' ? `Ratio ${odp.ratio_used}/${odp.ratio_total} (${used}/${capacity} Port)` : `${used} / ${capacity} Port`}
                              </span>
                           </div>
                           <span className='text-[10px] font-bold opacity-60'>
                              {usage}% Terpakai
                           </span>
                        </div>
                      </div>
                      <div className="h-1.5 w-full bg-secondary rounded-full overflow-hidden">
                        <div 
                            className={cn(
                                "h-full transition-all duration-1000 ease-out",
                                isFull ? "bg-red-500" : isNearFull ? "bg-orange-500" : "bg-primary"
                            )}
                            style={{ width: isMounted ? `${usage}%` : '0%' }}
                        />
                      </div>
                    </div>
                  )
                })
              )}
              {filteredAndSortedODP.length === 0 && !isLoading && (
                <div className='text-center py-10 text-muted-foreground font-bold italic text-sm'>
                   Data ODP tidak ditemukan.
                </div>
              )}
            </CardContent>

            {/* Professional Pagination Footer (Standard Style) */}
            <div className='flex items-center justify-between border-t px-6 py-4'>
                <div className='flex items-center gap-2'>
                    <Select
                        value={`${itemsPerPage}`}
                        onValueChange={(v) => {
                            setItemsPerPage(Number(v))
                            setCurrentPage(1)
                        }}
                    >
                        <SelectTrigger className='h-8 w-[70px] text-xs bg-background'>
                            <SelectValue placeholder={itemsPerPage} />
                        </SelectTrigger>
                        <SelectContent side='top'>
                            {[5, 10, 20, 50].map((size) => (
                                <SelectItem key={size} value={`${size}`} className="text-xs">
                                    {size}
                                </SelectItem>
                            ))}
                        </SelectContent>
                    </Select>
                    <p className='text-xs font-medium text-muted-foreground'>Rows per page</p>
                </div>

                <div className='flex items-center gap-6'>
                    <div className='text-xs font-medium'>
                        Page {currentPage} of {totalPages || 1}
                    </div>
                    <div className='flex items-center space-x-1.5'>
                        <Button
                            variant='outline'
                            className='size-8 p-0'
                            onClick={() => setCurrentPage(1)}
                            disabled={currentPage === 1}
                        >
                            <ChevronsLeft className='h-4 w-4' />
                        </Button>
                        <Button
                            variant='outline'
                            className='size-8 p-0'
                            onClick={() => setCurrentPage(prev => prev - 1)}
                            disabled={currentPage === 1}
                        >
                            <ChevronLeft className='h-4 w-4' />
                        </Button>

                        {/* Page Numbers */}
                        {pageNumbers.map((page, i) => (
                            <div key={i}>
                                {page === '...' ? (
                                    <span className='px-1 text-xs text-muted-foreground'>...</span>
                                ) : (
                                    <Button
                                        variant={currentPage === page ? 'default' : 'outline'}
                                        className='h-8 min-w-8 px-2 text-xs'
                                        onClick={() => setCurrentPage(page as number)}
                                    >
                                        {page}
                                    </Button>
                                )}
                            </div>
                        ))}

                        <Button
                            variant='outline'
                            className='size-8 p-0'
                            onClick={() => setCurrentPage(prev => prev + 1)}
                            disabled={currentPage === totalPages || totalPages === 0}
                        >
                            <ChevronRight className='h-4 w-4' />
                        </Button>
                        <Button
                            variant='outline'
                            className='size-8 p-0'
                            onClick={() => setCurrentPage(totalPages)}
                            disabled={currentPage === totalPages || totalPages === 0}
                        >
                            <ChevronsRight className='h-4 w-4' />
                        </Button>
                    </div>
                </div>
            </div>
          </Card>

          
        </div>
    
      </Main>

      <ODPDetailDialog 
        isOpen={!!selectedODP} 
        onClose={() => setSelectedODP(null)} 
        odp={selectedODP} 
      />
      <ODCDetailDialog
        isOpen={!!selectedODC}
        onClose={() => setSelectedODC(null)}
        odc={selectedODC}
      />
    </>
  )
}
