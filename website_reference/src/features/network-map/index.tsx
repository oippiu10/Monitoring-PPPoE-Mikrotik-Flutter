import { useEffect, useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { useRouterStore } from '@/stores/router-store'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { RouterSelector } from '@/components/router-selector'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { ThemeSwitch } from '@/components/theme-switch'
import { Card, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { 
    Map as MapIcon, Layers, Server, Share2, Search, 
    Pencil, CheckCircle2, XCircle, ChevronLeft,
    Users, Wifi, WifiOff, Box, Maximize2, LocateFixed
} from 'lucide-react'
import { toast } from 'sonner'
import { cn } from '@/lib/utils'
import { usePermission } from '@/lib/permissions'
import { PrivacyToggle } from '@/components/privacy'
import { usePrivacyStore } from '@/stores/privacy-store'

declare const L: any

const popupStyles = `
  .map-marker-wrap { background: transparent !important; border: 0 !important; }
  .mn-marker { position: relative; display:flex; align-items:center; justify-content:center; border:3px solid #fff; box-shadow:0 10px 24px rgba(15,23,42,.35); cursor:pointer; pointer-events:auto; }
  .mn-marker::after { content:''; position:absolute; inset:-7px; border-radius:inherit; background:currentColor; opacity:.16; animation:mn-pulse 2s infinite; }
  .mn-marker svg { position:relative; z-index:1; filter:drop-shadow(0 1px 1px rgba(0,0,0,.25)); }
  .mn-server { width:44px; height:44px; border-radius:14px; color:#ef4444; background:linear-gradient(135deg,#ef4444,#7f1d1d); }
  .mn-odc { width:38px; height:38px; border-radius:12px; color:#f59e0b; background:linear-gradient(135deg,#f59e0b,#b45309); }
  .mn-odp { width:34px; height:34px; border-radius:999px; }
  .mn-user { width:30px; height:30px; border-radius:12px; }
  .mn-user.online { color:#22c55e; background:linear-gradient(135deg,#22c55e,#047857); }
  .mn-user.offline { color:#ef4444; background:linear-gradient(135deg,#ef4444,#b91c1c); }
  .mn-user.disabled { color:#7f1d1d; background:linear-gradient(135deg,#f43f5e,#7f1d1d); }
  .mn-label { position:absolute; left:50%; top:100%; transform:translateX(-50%); margin-top:4px; max-width:110px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; border-radius:999px; background:rgba(15,23,42,.82); color:white; padding:2px 7px; font-size:9px; font-weight:900; letter-spacing:.02em; box-shadow:0 4px 12px rgba(0,0,0,.25); pointer-events:none; }
  .marker-cluster-small, .marker-cluster-medium, .marker-cluster-large { background:rgba(37,99,235,.18) !important; }
  .marker-cluster div { background:linear-gradient(135deg,#2563eb,#7c3aed) !important; color:white !important; font-weight:900 !important; border:3px solid white; box-shadow:0 8px 22px rgba(37,99,235,.38); }
  .leaflet-overlay-pane path.cable-flow { stroke-dasharray: 16 12; animation: cable-flow 1.1s linear infinite; filter: drop-shadow(0 0 5px rgba(255,255,255,.55)); }
  .leaflet-overlay-pane path.cable-flow.offline { stroke-dasharray: 10 12; animation-duration: 1.4s; }
  .leaflet-overlay-pane path.backbone-flow { stroke-dasharray: 20 15; animation: backbone-flow 1.5s linear infinite; filter: drop-shadow(0 0 6px rgba(99,102,241,0.6)); }
  @keyframes cable-flow { to { stroke-dashoffset: -56; } }
  @keyframes backbone-flow { to { stroke-dashoffset: -70; } }
  @keyframes mn-pulse { 0%,100%{transform:scale(.88);opacity:.12} 50%{transform:scale(1.18);opacity:.22} }
  .premium-popup { z-index: 1200 !important; }
  .premium-popup a { text-decoration: none !important; }
  .premium-popup a.text-white { color: #ffffff !important; }
  .premium-popup a.text-slate-600 { color: #475569 !important; }
  .dark .premium-popup a.dark\\:text-slate-300 { color: #cbd5e1 !important; }
  .premium-popup .leaflet-popup-content-wrapper {
    background: transparent !important;
    border: none !important;
    box-shadow: none !important;
    padding: 0 !important;
    margin: 0 !important;
  }
  .premium-popup .leaflet-popup-content {
    margin: 0 !important;
    width: auto !important;
  }
  .premium-popup .leaflet-popup-tip-container {
    display: none !important;
  }
  .premium-popup .leaflet-popup-close-button {
    display: none !important;
  }
`

const calculateLineDistance = (path: any[]) => {
    if (!path || path.length < 2) return 0
    let totalDistance = 0
    for (let i = 0; i < path.length - 1; i++) {
        try {
            const p1 = L.latLng(path[i])
            const p2 = L.latLng(path[i+1])
            totalDistance += p1.distanceTo(p2)
        } catch (e) {
            console.error("Error calculating segment distance", e)
        }
    }
    return totalDistance
}

const calculateDistanceAlongPath = (path: any[], latlng: any) => {
    if (!path || path.length < 2) return 0
    let minDistance = Infinity
    let closestSegmentIdx = 0
    let closestPoint: any = latlng

    for (let i = 0; i < path.length - 1; i++) {
        try {
            const p1 = L.latLng(path[i])
            const p2 = L.latLng(path[i+1])

            // Proyeksikan latlng ke segmen garis p1-p2 menggunakan Leaflet.LineUtil
            // Karena LineUtil.closestPointOnSegment bekerja pada objek L.Point, kita ubah latlng ke point flat (menggunakan koordinat mentah lng, lat sebagai x, y)
            const mapPoint = L.point(latlng.lng, latlng.lat)
            const pt1 = L.point(p1.lng, p1.lat)
            const pt2 = L.point(p2.lng, p2.lat)
            
            const ptClosest = L.LineUtil.closestPointOnSegment(mapPoint, pt1, pt2)
            const projLatLng = L.latLng(ptClosest.y, ptClosest.x)
            const dist = latlng.distanceTo(projLatLng)

            if (dist < minDistance) {
                minDistance = dist
                closestSegmentIdx = i
                closestPoint = projLatLng
            }
        } catch (e) {
            // Abaikan jika terjadi parsing latlng error
        }
    }

    let distance = 0
    for (let i = 0; i < closestSegmentIdx; i++) {
        try {
            distance += L.latLng(path[i]).distanceTo(L.latLng(path[i+1]))
        } catch (e) { /* ignore */ }
    }
    try {
        distance += L.latLng(path[closestSegmentIdx]).distanceTo(closestPoint)
    } catch (e) { /* ignore */ }
    
    return distance
}

const formatDistance = (meters: number) => {
    if (meters < 1000) {
        return `${Math.round(meters)} m`
    }
    return `${(meters / 1000).toFixed(2)} km`
}

export default function NetworkMap() {
  useEffect(() => {
    const style = document.createElement('style')
    style.innerHTML = popupStyles
    document.head.appendChild(style)
    return () => { document.head.removeChild(style) }
  }, [])

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (searchContainerRef.current && !searchContainerRef.current.contains(e.target as Node)) {
        setShowSuggestions(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const { activeRouter } = useRouterStore()
  const permissions = usePermission()
  const privacyMode = usePrivacyStore((state) => state.privacyMode)
  const [showStats, setShowStats] = useState(true)
  const mapRef = useRef<HTMLDivElement>(null)
  const [mapInstance, setMapInstance] = useState<any>(null)
  const [clusterGroup, setClusterGroup] = useState<any>(null)
  const elementsRef = useRef<any[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [showSuggestions, setShowSuggestions] = useState(false)
  const searchContainerRef = useRef<HTMLDivElement>(null)
  const [layers, setLayers] = useState({
    cablesBackbone: false,
    cablesCustomer: true,
    odcs: true,
    odps: true,
    users: true,
    lines: true
  })
  const [statusFilter, setStatusFilter] = useState<'all' | 'online' | 'offline'>('all')
  const [activeFooterInfo, setActiveFooterInfo] = useState<string | null>(null)

  const toggleFooterInfo = (key: string) => setActiveFooterInfo(prev => prev === key ? null : key)

  const maskText = (text: string) => {
      if (!privacyMode) return text
      if (!text) return ''
      if (text.includes('@')) {
          const parts = text.split('@')
          const firstPart = parts[0]
          const secondPart = parts[1]
          const maskedFirst = firstPart.length <= 2 ? firstPart + '***' : firstPart.substring(0, 2) + '***'
          const maskedSecond = secondPart.length <= 3 ? '***' : secondPart.substring(0, 3) + '***'
          return maskedFirst + '@' + maskedSecond
      }
      if (text.length <= 4) return '***'
      return text.substring(0, 2) + '***' + text.substring(text.length - 2)
  }

  // Cable editing state
  const [editingCable, setEditingCable] = useState<{
    type: 'backbone' | 'customer'
    targetId: string
    displayName: string
    path: [number, number][]
    originalPath: [number, number][]
    id?: number
  } | null>(null)
  const editMarkersRef = useRef<any[]>([])
  const editPolylineRef = useRef<any>(null)

  // Drawing state
  const [isDrawing, setIsDrawing] = useState(false)
  const [drawPoints, setDrawPoints] = useState<any[]>([])
  const tempLineRef = useRef<any>(null)
  const markerInstancesRef = useRef<{
    users: Record<string, any>
    odps: Record<string, any>
    odcs: Record<string, any>
  }>({ users: {}, odps: {}, odcs: {} })
  const queryClient = useQueryClient()
  const lastFittedId = useRef<number | null>(null)

  // Data Queries
  const { data: odpList } = useQuery({
    queryKey: ['odps', activeRouter?.id],
    queryFn: async () => {
      const res = await api.get('/odp.php', { params: { router_id: activeRouter?.id } })
      return res.data.data || []
    },
    enabled: !!activeRouter,
  })

  const { data: odcList } = useQuery({
    queryKey: ['odcs', activeRouter?.id],
    queryFn: async () => {
      const res = await api.get('/odc.php', { params: { router_id: activeRouter?.id } })
      return res.data.data || []
    },
    enabled: !!activeRouter,
  })

  const { data: usersList } = useQuery({
    queryKey: ['users-map', activeRouter?.id],
    queryFn: async () => {
        const res = await api.get('/get_all_users_paginated.php', {
            params: { router_id: activeRouter?.id, per_page: 9999 }
        })
        return res.data.data || []
    },
    enabled: !!activeRouter,
  })

  const { data: linesList } = useQuery({
    queryKey: ['network-lines', activeRouter?.id],
    queryFn: async () => {
        const res = await api.get('/network_lines.php', { params: { router_id: activeRouter?.id } })
        return res.data.data || []
    },
    enabled: !!activeRouter,
  })

  const { data: routerSummary } = useQuery({
    queryKey: ['router-summary', activeRouter?.id],
    queryFn: async () => {
        const res = await api.get('/mikrotik_live.php', { 
            params: { router_id: activeRouter?.id, cmd: 'summary' } 
        })
        return res.data.data || null
    },
    enabled: !!activeRouter,
    refetchInterval: 2000,
  })

  const { data: acsDevices } = useQuery({
    queryKey: ['genieacs-devices'],
    queryFn: async () => {
      const projection = [
        '_id',
        '_lastInform',
        'VirtualParameters.pppoeUsername',
        'VirtualParameters.RXPower',
        'VirtualParameters.gettemp',
        'VirtualParameters.activedevices',
        'VirtualParameters.getdeviceuptime',
        'VirtualParameters.pppoeIP',
        'InternetGatewayDevice.DeviceInfo.ModelName',
        'Device.DeviceInfo.ProductClass',
        'InternetGatewayDevice.DeviceInfo.UpTime',
        'InternetGatewayDevice.LANDevice.1.Hosts.Host',
        'Device.Hosts.Host'
      ].join(',')
      const res = await api.get(`/genieacs_proxy.php?path=/devices&projection=${encodeURIComponent(projection)}`)
      return res.data || []
    },
    refetchInterval: 15000,
    staleTime: 10000,
  })

  const isValidCoordinate = (lat: any, lng: any) => {
    const latNum = Number(lat)
    const lngNum = Number(lng)
    if (!Number.isFinite(latNum) || !Number.isFinite(lngNum)) return false
    if (Math.abs(latNum) < 0.000001 && Math.abs(lngNum) < 0.000001) return false
    return Math.abs(latNum) <= 90 && Math.abs(lngNum) <= 180
  }

  const cancelEditCable = () => {
    setEditingCable(null)
    toast.success('Edit jalur kabel dibatalkan')
  }

  const resetToStraight = async () => {
    if (!editingCable) return
    if (!editingCable.id) {
        setEditingCable(null)
        toast.success('Jalur dikembalikan ke lurus')
        return
    }
    toast.loading('Mengembalikan ke jalur lurus...', { id: 'reset-cable' })
    try {
        await api.delete('/network_lines.php', { params: { id: editingCable.id } })
        toast.success('Jalur kabel dikembalikan ke lurus', { id: 'reset-cable' })
        setEditingCable(null)
        queryClient.invalidateQueries({ queryKey: ['network-lines'] })
    } catch (err) {
        toast.error('Gagal mereset jalur kabel', { id: 'reset-cable' })
    }
  }

  const saveCablePath = async () => {
    if (!editingCable) return
    const { type, targetId, path, id } = editingCable
    if (path.length < 2) {
        toast.error('Jalur kabel minimal harus memiliki 2 titik')
        return
    }
    toast.loading('Menyimpan perubahan jalur...', { id: 'save-cable' })
    try {
        if (id) {
            await api.delete('/network_lines.php', { params: { id } })
        }
        const apiPath = path.map(p => ({ lat: p[0], lng: p[1] }))
        const name = type === 'backbone' ? `backbone_odp_${targetId}` : `customer_user_${targetId}`
        
        let sourceId = ''
        let targetIdVal = targetId

        if (type === 'backbone') {
            const odp = odpList?.find((o: any) => String(o.id) === String(targetId))
            if (odp) {
                if (odp.parent_id) {
                    sourceId = `odp_${odp.parent_id}`
                } else if (odp.odc_id) {
                    sourceId = `odc_${odp.odc_id}`
                } else {
                    sourceId = `router_${activeRouter?.id || ''}`
                }
                targetIdVal = `odp_${targetId}`
            }
        } else {
            const user = usersList?.find((u: any) => String(u.username) === String(targetId))
            if (user) {
                sourceId = `odp_${user.odp_id}`
                targetIdVal = `user_${targetId}`
            }
        }

        await api.post('/network_lines.php', {
            router_id: activeRouter?.software_id || activeRouter?.id || '',
            name,
            type,
            path: apiPath,
            color: type === 'backbone' ? '#6366f1' : '#22c55e',
            source_id: sourceId,
            target_id: targetIdVal
        })
        toast.success('Perubahan jalur kabel disimpan!', { id: 'save-cable' })
        setEditingCable(null)
        queryClient.invalidateQueries({ queryKey: ['network-lines'] })
    } catch (err) {
        toast.error('Gagal menyimpan perubahan jalur', { id: 'save-cable' })
    }
  }

  const getNestedParam = (obj: any, path: string) => {
      if (!obj) return ''
      const parts = path.split('.')
      let current = obj
      for (const part of parts) {
          if (current && typeof current === 'object' && part in current) current = current[part]
          else return ''
      }
      if (current === null || current === undefined) return ''
      if (typeof current === 'string' || typeof current === 'number') return String(current)
      if (current._value !== undefined) return String(current._value)
      if (current.value !== undefined) return String(current.value)
      return ''
  }

  const formatBps = (bits: any) => {
    const b = parseInt(bits || '0')
    if (b < 1000) return b + ' bps'
    if (b < 1000000) return (b / 1000).toFixed(1) + ' Kbps'
    return (b / 1000000).toFixed(1) + ' Mbps'
  }

  const totalUsers = usersList?.length || 0
  const onlineUsers = usersList?.filter((u: any) => u.status === 'online').length || 0
  const offlineUsers = Math.max(totalUsers - onlineUsers, 0)
  const totalOdc = odcList?.length || 0
  const totalOdp = odpList?.length || 0
  const totalManualLines = linesList?.length || 0
  const usedPorts = odpList?.reduce((sum: number, odp: any) => sum + Number(odp.total_users || 0), 0) || 0
  const totalPorts = odpList?.reduce((sum: number, odp: any) => {
    const cap = odp.type === 'ratio'
      ? Number(odp.ratio_total || 0)
      : Number(String(odp.splitter_type || '').split(':')[1] || 0)
    return sum + cap
  }, 0) || 0
  const capacityPercent = totalPorts > 0 ? Math.round((usedPorts / totalPorts) * 100) : 0

  // Determine if any query is loading (for loading overlay)
  const isMapLoading = !odpList && !odcList && !usersList

  // Initialize Map
  useEffect(() => {
    if (!mapRef.current || mapInstance) return

    let center: [number, number] = [-6.9, 110.4]
    if (activeRouter?.lat && activeRouter?.lng && !(Math.abs(Number(activeRouter.lat)) < 0.000001 && Math.abs(Number(activeRouter.lng)) < 0.000001)) {
      center = [parseFloat(activeRouter.lat), parseFloat(activeRouter.lng)]
    }

    const map = L.map(mapRef.current, {
        zoomControl: false,
        maxZoom: 24
    }).setView(center, 14)
    
    L.tileLayer('https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', {
      maxZoom: 24,
      maxNativeZoom: 20,
      subdomains: ['0', '1', '2', '3'],
      attribution: '&copy; Google Maps'
    }).addTo(map)

    L.control.zoom({ position: 'bottomright' }).addTo(map)

    const clusters = L.markerClusterGroup({
        showCoverageOnHover: false,
        maxClusterRadius: 55,
        spiderfyOnMaxZoom: true,
        disableClusteringAtZoom: 18
    })
    map.addLayer(clusters)
    
    setClusterGroup(clusters)
    setMapInstance(map)
    
    if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
            (pos) => {
                map.flyTo([pos.coords.latitude, pos.coords.longitude], 15, { duration: 2 })
                toast.success('Lokasi Anda terdeteksi')
            },
            () => console.log('Geolocation failed')
        )
    }
    
    setTimeout(() => map.invalidateSize(), 300)

    return () => {
        map.remove()
        setMapInstance(null)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Drawing Events
  useEffect(() => {
    if (!mapInstance) return
    if (isDrawing) {
        mapInstance.getContainer().style.cursor = 'crosshair'
        const onClick = (e: any) => {
            setDrawPoints(prev => [...prev, [e.latlng.lat, e.latlng.lng]])
        }
        mapInstance.on('click', onClick)
        return () => {
            mapInstance.off('click', onClick)
            mapInstance.getContainer().style.cursor = ''
        }
    }
  }, [mapInstance, isDrawing])

  useEffect(() => {
    if (!mapInstance) return
    if (tempLineRef.current) tempLineRef.current.remove()
    if (drawPoints.length > 1) {
        tempLineRef.current = L.polyline(drawPoints, { 
            color: '#f97316', 
            weight: 4, 
            dashArray: '5, 10',
            opacity: 0.8
        }).addTo(mapInstance)
    }
  }, [mapInstance, drawPoints])

  // Helper: ODP Capacity Color
  const getODPColor = (used: number, total: number) => {
    if (!total || total === 0) return '#3b82f6'
    const pct = (used / total) * 100
    if (pct >= 90) return '#ef4444'
    if (pct >= 70) return '#f59e0b'
    return '#22c55e'
  }

  // Update Map Content
  useEffect(() => {
    if (!mapInstance || !clusterGroup) return

    elementsRef.current.forEach(el => el.remove())
    elementsRef.current = []
    clusterGroup.clearLayers()
    markerInstancesRef.current = { users: {}, odps: {}, odcs: {} }

    const bounds = L.latLngBounds([])
    let hasPoints = false

    // 1. Router
    // Handle Router Marker
    const rLat = parseFloat(activeRouter?.lat || '0')
    const rLng = parseFloat(activeRouter?.lng || '0')
    
    if (rLat !== 0 && rLng !== 0 && mapInstance) {
        const rPos: [number, number] = [rLat, rLng]
        
        // Find existing router marker in elementsRef
        let rMarker = (elementsRef.current as any[]).find(el => el._isRouter)
        
        if (!rMarker) {
            rMarker = L.marker(rPos, {
                icon: L.divIcon({
                    className: 'map-marker-wrap',
                    html: `<div class="mn-marker mn-server"><svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><line x1="6" y1="6" x2="6.01" y2="6"/><line x1="6" y1="18" x2="6.01" y2="18"/></svg><span class="mn-label">SERVER</span></div>`,
                    iconSize: [44, 54],
                    iconAnchor: [22, 22]
                })
            }).addTo(mapInstance)
            rMarker._isRouter = true
            elementsRef.current.push(rMarker)
        } else {
            rMarker.setLatLng(rPos)
        }

        const isFetching = !routerSummary
        const res = routerSummary?.resource
        const identity = routerSummary?.identity || 'SERVER UTAMA'
        const topIf = routerSummary?.top_interface
        const internet = routerSummary?.internet || 'Error'

        const cpu = res?.['cpu-load'] !== undefined ? `${res['cpu-load']}%` : '...'
        const uptime = res?.uptime || '...'
        const model = res?.['board-name'] || '...'
        
        const popupContent = `
            <div class='w-[230px] overflow-hidden rounded-xl bg-[#1e293b]/95 text-white shadow-xl'>
                <div class='flex items-center justify-between gap-2 border-b border-white/10 bg-blue-600/30 px-3 py-2.5'>
                    <b class='min-w-0 truncate text-xs font-black uppercase'>${identity}</b>
                    <span class='shrink-0 rounded-lg bg-white/15 px-2 py-0.5 text-[9px] font-black uppercase'>${isFetching ? 'Sync' : 'Online'}</span>
                </div>

                <div class='space-y-2 p-3'>
                    ${isFetching ? `
                        <div class='flex flex-col items-center justify-center gap-2 py-5 text-slate-500'>
                            <div class='w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin'></div>
                            <span class='text-[10px] font-bold uppercase tracking-widest'>Connecting...</span>
                        </div>
                    ` : `
                    <div class='flex items-center justify-between gap-2 rounded-lg bg-black/25 p-2'>
                        <span class='text-[9px] font-black uppercase text-slate-400'>Model</span>
                        <span class='truncate text-[10px] font-black text-slate-200'>${model}</span>
                    </div>

                    <div class='flex items-center justify-between'>
                        <div class='flex items-center gap-3 text-slate-400'>
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="4" width="16" height="16" rx="2" /><rect x="9" y="9" width="6" height="6" /><line x1="15" y1="2" x2="15" y2="4" /><line x1="9" y1="2" x2="9" y2="4" /><line x1="15" y1="20" x2="15" y2="22" /><line x1="9" y1="20" x2="9" y2="22" /><line x1="22" y1="15" x2="20" y2="15" /><line x1="22" y1="9" x2="20" y2="9" /><line x1="4" y1="15" x2="2" y2="15" /><line x1="4" y1="9" x2="2" y2="9" /></svg>
                            <span class='text-[11px] font-bold'>CPU</span>
                        </div>
                        <span class='text-[11px] font-black text-green-400'>${cpu}</span>
                    </div>

                    <div class='flex items-center justify-between'>
                        <div class='flex items-center gap-3 text-slate-400'>
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                            <span class='text-[11px] font-bold'>Uptime</span>
                        </div>
                        <span class='text-[11px] font-black text-orange-400'>${uptime}</span>
                    </div>

                    <div class='flex items-center justify-between'>
                        <div class='flex items-center gap-3 text-slate-400'>
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
                            <span class='text-[11px] font-bold'>Internet (8.8.8.8)</span>
                        </div>
                        <span class='text-[11px] font-black ${internet === 'OK' ? 'text-green-400' : 'text-red-500'}'>${internet}</span>
                    </div>

                    ${topIf ? `
                    <div class='space-y-2 rounded-lg bg-black/30 p-2'>
                        <div class='flex items-center gap-2'>
                            <span class='text-[9px] font-black uppercase text-cyan-400 tracking-widest'>TRAFFIC ${topIf.name}</span>
                        </div>
                        <div class='flex justify-between'>
                            <div class='flex items-center gap-2'>
                                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class='text-green-400'><path d="m19 12-7 7-7-7"/><path d="M12 19V5"/></svg>
                                <span class='text-[13px] font-black'>${formatBps(topIf.bps_rx)}</span>
                            </div>
                            <div class='flex items-center gap-2'>
                                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class='text-blue-400'><path d="m5 12 7-7 7 7"/><path d="M12 5v14"/></svg>
                                <span class='text-[13px] font-black'>${formatBps(topIf.bps_tx)}</span>
                            </div>
                        </div>
                    </div>
                    ` : ''}
                    `}
                </div>
            </div>
        `

        // Update popup content without closing it if possible, or bind normally
        rMarker.bindPopup(popupContent, { 
            className: 'premium-popup',
            autoPan: true,
            autoPanPadding: [24, 24],
            closeButton: false,
            maxWidth: 250
        })
        rMarker.on('click', () => rMarker.openPopup())

        // If popup is open, update its content live
        if (rMarker.isPopupOpen()) {
            rMarker.setPopupContent(popupContent)
        }

        bounds.extend(rPos)
        hasPoints = true
    }

    // 1.5 ODC
    if (odcList && layers.odcs) {
        odcList.forEach((odc: any) => {
            if (isValidCoordinate(odc.lat, odc.lng)) {
                const pos: [number, number] = [parseFloat(odc.lat), parseFloat(odc.lng)]
                const marker = L.marker(pos, {
                    icon: L.divIcon({
                        className: 'map-marker-wrap',
                        html: `<div class="mn-marker mn-odc"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="8" x="2" y="3" rx="2"/><rect width="20" height="8" x="2" y="13" rx="2"/><line x1="6" y1="7" x2="6.01" y2="7"/><line x1="6" y1="17" x2="6.01" y2="17"/></svg><span class="mn-label">${odc.name}</span></div>`,
                        iconSize: [38, 50],
                        iconAnchor: [19, 19]
                    })
                })

                const connectedOdps = odpList?.filter((o: any) => String(o.odc_id) === String(odc.id) && isValidCoordinate(o.lat, o.lng)) || []

                marker.bindPopup(`
                    <div class='w-[240px] overflow-hidden rounded-xl bg-white text-slate-900 shadow-xl dark:bg-slate-900 dark:text-white'>
                        <div class='px-3 py-2 bg-amber-600 text-white'>
                            <div class='flex items-center justify-between gap-2'>
                                <h4 class='min-w-0 truncate text-xs font-black'>${odc.name}</h4>
                                <span class='shrink-0 rounded-lg bg-white/20 px-2 py-0.5 text-[9px] font-black uppercase'>ODC</span>
                            </div>
                        </div>
                        <div class='space-y-2 p-3 max-h-[260px] overflow-y-auto custom-scrollbar'>
                            <div class='grid grid-cols-2 gap-1.5'>
                                <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70'>
                                    <p class='truncate text-[11px] font-black'>${privacyMode ? '•••' : (odc.capacity || 12)} Port</p>
                                    <p class='text-[8px] font-black uppercase text-slate-500'>Kapasitas</p>
                                </div>
                                <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70'>
                                    <p class='truncate text-[11px] font-black'>${privacyMode ? '•••' : connectedOdps.length} ODP</p>
                                    <p class='text-[8px] font-black uppercase text-slate-500'>Terhubung</p>
                                </div>
                            </div>
                            ${odc.location ? `<p class='line-clamp-2 rounded-lg bg-slate-50 p-2 text-[9px] font-bold text-slate-500 dark:bg-slate-800/70'>${privacyMode ? 'Lokasi Disembunyikan (Privacy ON)' : odc.location}</p>` : ''}
                            ${odc.notes ? `<p class='rounded-lg bg-amber-50 dark:bg-amber-950/20 p-2 text-[9px] font-bold text-amber-600 dark:text-amber-400'>${odc.notes}</p>` : ''}
                            <a href='/odp/odc?search=${odc.name}' target='_blank' class='block mt-2 rounded-lg border border-slate-200 dark:border-slate-700 px-2 py-2 text-center text-[9px] font-black uppercase text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors'>Buka Detail ODC →</a>
                        </div>
                    </div>
                `, { className: 'premium-popup', closeButton: false, autoPan: true, autoPanPadding: [24, 24], maxWidth: 240 })

                marker.on('click', () => marker.openPopup())
                clusterGroup.addLayer(marker)
                markerInstancesRef.current.odcs[String(odc.id)] = marker
                bounds.extend(pos)
                hasPoints = true
            }
        })
    }

    // 2. ODP
    if (odpList && layers.odps) {
        odpList.forEach((odp: any) => {
            if (isValidCoordinate(odp.lat, odp.lng)) {
                const pos = [parseFloat(odp.lat), parseFloat(odp.lng)]
                const used = Number(odp.total_users || 0)
                const splitterCapacity = odp.splitter_type ? Number(String(odp.splitter_type).split(':')[1] || 0) : 0
                const total = odp.type === 'ratio'
                  ? Number(odp.ratio_total || 0)
                  : splitterCapacity
                const pct = total > 0 ? Math.round((used / total) * 100) : 0
                const color = getODPColor(used, total)
                const odpTypeBadge = odp.type === 'ratio'
                  ? `<span style='background:rgba(249,115,22,0.25);color:#fb923c;font-size:7px;font-weight:900;letter-spacing:.05em;padding:1px 4px;border-radius:4px;margin-left:4px;'>RATIO ${odp.ratio_used}/${odp.ratio_total}</span>`
                  : `<span style='background:rgba(99,102,241,0.2);color:#818cf8;font-size:7px;font-weight:900;letter-spacing:.05em;padding:1px 4px;border-radius:4px;margin-left:4px;'>${odp.splitter_type || 'SPL'}</span>`
                const marker = L.marker(pos, {
                    icon: L.divIcon({
                        className: 'map-marker-wrap',
                        html: `<div class="mn-marker mn-odp" style="color:${color};background:linear-gradient(135deg,${color},#0f172a)"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><path d="M3.3 7 12 12l8.7-5"/><path d="M12 22V12"/></svg><span class="mn-label">${odp.name}</span></div>`,
                        iconSize: [34, 46],
                        iconAnchor: [17, 17]
                    })
                })
                const odpUsers = usersList?.filter((u: any) => String(u.odp_id) === String(odp.id)) || []
                const remainingPorts = total > 0 ? Math.max(total - used, 0) : 0
                const portCount = total > 0 ? Math.min(total, 64) : 0
                const portBoxes = portCount > 0 ? Array.from({ length: portCount }).map((_, i) => {
                    const filled = i < used
                    return `<span title='Port ${i + 1} ${filled ? 'terpakai' : 'kosong'}' class='inline-block h-3 w-3 rounded-[3px] border ${filled ? 'border-emerald-600 bg-emerald-500' : 'border-slate-300 bg-slate-100 dark:border-slate-700 dark:bg-slate-800'}'></span>`
                }).join('') : ''
                const userRows = odpUsers.slice(0, 5).map((u: any, i: number) => {
                    const acsDevice = acsDevices?.find((d: any) => getNestedParam(d, 'VirtualParameters.pppoeUsername') === u.username)
                    const redamanLive = acsDevice ? getNestedParam(acsDevice, 'VirtualParameters.RXPower') : null
                    const redamanAwal = u.redaman
                    
                    const badge = redamanLive ? 
                        `<span class='shrink-0 rounded bg-blue-100 px-1 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400'>${redamanLive} dB</span>` : 
                        (redamanAwal ? `<span class='shrink-0 rounded bg-slate-100 px-1 text-slate-500 dark:bg-slate-800 dark:text-slate-400'>${redamanAwal} dB</span>` : `<span class='shrink-0 text-slate-400'>-</span>`)
                        
                    return `
                    <div class='flex items-center justify-between gap-2 border-b border-slate-100 py-1 text-[10px] last:border-0 dark:border-slate-800'>
                        <span class='min-w-0 truncate font-bold'>${i + 1}. ${maskText(u.username)}</span>
                        ${badge}
                    </div>
                `}).join('')
                const displayOdpAlamat = privacyMode ? 'Lokasi Disembunyikan (Privacy ON)' : (odp.location || odp.alamat)
                marker.bindPopup(`
                    <div class='w-[250px] overflow-hidden rounded-xl bg-white text-slate-900 shadow-xl dark:bg-slate-900 dark:text-white'>
                        <div style='background:${color}' class='px-3 py-2.5 text-white'>
                            <div class='flex items-center justify-between gap-2'>
                                <div class='min-w-0 flex-1'>
                                    <div class='flex items-center gap-1'>
                                      <p class='text-[8px] font-black uppercase tracking-widest opacity-80'>ODP</p>
                                      ${odpTypeBadge}
                                    </div>
                                    <h4 class='truncate text-xs font-black'>${odp.name}</h4>
                                </div>
                                <div class='shrink-0 rounded-lg bg-white/20 px-2 py-0.5 text-[10px] font-black'>${used}/${total || '?'}</div>
                            </div>
                            ${odp.rx_power ? `<div class='mt-1 flex items-center justify-between rounded-md bg-white/10 px-2 py-1'><span class='text-[9px] font-bold opacity-80'>Rx Sumber</span><span class='font-mono text-[10px] font-black'>${odp.rx_power} dBm</span></div>` : ''}
                        </div>
                        <div class='space-y-2 p-3 max-h-[260px] overflow-y-auto custom-scrollbar'>
                            <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70'>
                                <div class='mb-1.5 flex justify-between text-[9px] font-black uppercase text-slate-500'>
                                    <span>Port Terpakai</span><span>${pct}%</span>
                                </div>
                                ${portBoxes ? `<div class='flex flex-wrap gap-1'>${portBoxes}</div>` : `<p class='text-[10px] font-bold text-slate-400'>Kapasitas belum diisi</p>`}
                            </div>
                            <div class='grid grid-cols-3 gap-1.5 text-center'>
                                <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70'><p class='text-sm font-black'>${total || '-'}</p><p class='text-[8px] font-black uppercase text-slate-500'>Port</p></div>
                                <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70'><p class='text-sm font-black text-emerald-600'>${used}</p><p class='text-[8px] font-black uppercase text-slate-500'>Pakai</p></div>
                                <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70'><p class='text-sm font-black text-blue-600'>${remainingPorts}</p><p class='text-[8px] font-black uppercase text-slate-500'>Sisa</p></div>
                            </div>
                            ${odpUsers.length ? `<div class='rounded-lg bg-slate-50 px-2 py-1.5 dark:bg-slate-800/70'><div class='mb-1 text-[8px] font-black uppercase text-slate-500'>Pelanggan</div>${userRows}${odpUsers.length > 5 ? `<p class='pt-1 text-center text-[9px] font-black text-slate-400'>+${odpUsers.length - 5} lainnya</p>` : ''}</div>` : ''}
                            ${displayOdpAlamat ? `<p class='truncate rounded-lg bg-slate-50 p-2 text-[9px] font-bold text-slate-500 dark:bg-slate-800/70'>${displayOdpAlamat}</p>` : ''}
                            ${odp.maps_link ? `<a href='${odp.maps_link}' target='_blank' class='flex items-center justify-center gap-1 rounded-lg border border-slate-200 dark:border-slate-700 px-2 py-2 text-center text-[9px] font-black uppercase text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors'><svg class='h-3 w-3 shrink-0' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'><path d='M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z'/><circle cx='12' cy='10' r='3'/></svg>Buka Google Maps</a>` : ''}
                            <a href='/odp?search=${odp.name}' target='_blank' class='block mt-1 rounded-lg border border-slate-200 dark:border-slate-700 px-2 py-2 text-center text-[9px] font-black uppercase text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors'>Buka Detail ODP →</a>
                        </div>
                    </div>
                `, { className: 'premium-popup', closeButton: false, autoPan: true, autoPanPadding: [24, 24], maxWidth: 260 })
                marker.on('click', () => marker.openPopup())
                clusterGroup.addLayer(marker)
                markerInstancesRef.current.odps[String(odp.id)] = marker
                bounds.extend(pos)
                hasPoints = true
            }
        })
    }

    // 3. Users
    if (usersList && layers.users) {
        usersList
          .filter((user: any) => statusFilter === 'all' || user.status === statusFilter)
          .forEach((user: any) => {
            if (isValidCoordinate(user.lat, user.lng)) {
                const pos = [parseFloat(user.lat), parseFloat(user.lng)]
                const isDisabled = user.disabled === 'yes'
                const markerClass = isDisabled ? 'disabled' : user.status === 'online' ? 'online' : 'offline'
                const marker = L.marker(pos, {
                    icon: L.divIcon({
                        className: 'map-marker-wrap',
                        html: `<div class="mn-marker mn-user ${markerClass}"><svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 10v10h14V10"/><path d="M9 20v-6h6v6"/></svg><span class="mn-label">${maskText(user.username)}</span></div>`,
                        iconSize: [30, 42],
                        iconAnchor: [15, 15]
                    })
                })
                const profile = user.profile || user.paket || '-'
                const acsDevice = acsDevices?.find((d: any) => getNestedParam(d, 'VirtualParameters.pppoeUsername') === user.username)
                
                const getConnectedHosts = (d: any) => {
                    if (!d) return []
                    const hosts: any[] = []
                    const searchForHosts = (obj: any) => {
                        if (!obj || typeof obj !== 'object') return
                        if (obj.MACAddress && obj.MACAddress._value) {
                            const ip = obj.IPAddress?._value || '-'
                            const activeVal = obj.Active?._value
                            if (activeVal === undefined || activeVal === true || activeVal === 'true' || activeVal === '1') {
                                hosts.push({
                                    name: obj.HostName?._value || 'Unknown Device',
                                    ip: ip === '0.0.0.0' ? '-' : ip,
                                    mac: obj.MACAddress._value || '-'
                                })
                            }
                            return
                        }
                        for (const k in obj) {
                            if (typeof obj[k] === 'object') {
                                searchForHosts(obj[k])
                            }
                        }
                    }
                    searchForHosts(d)
                    return hosts
                }

                const redamanLive = acsDevice ? getNestedParam(acsDevice, 'VirtualParameters.RXPower') : null
                const redamanAwal = user.redaman
                const model = acsDevice ? (getNestedParam(acsDevice, 'Device.DeviceInfo.ProductClass') || getNestedParam(acsDevice, 'InternetGatewayDevice.DeviceInfo.ModelName')) : null
                const temp = acsDevice ? getNestedParam(acsDevice, 'VirtualParameters.gettemp') : null
                const wifiClients = acsDevice ? getNestedParam(acsDevice, 'VirtualParameters.activedevices') : null
                const uptimeRaw = acsDevice ? getNestedParam(acsDevice, 'VirtualParameters.getdeviceuptime') || getNestedParam(acsDevice, 'InternetGatewayDevice.DeviceInfo.UpTime') : null
                
                let uptime = '-'
                if (uptimeRaw && !isNaN(Number(uptimeRaw))) {
                    const secs = Number(uptimeRaw)
                    if (secs > 86400) uptime = `${Math.floor(secs / 86400)}d`
                    else if (secs > 3600) uptime = `${Math.floor(secs / 3600)}h`
                    else if (secs > 60) uptime = `${Math.floor(secs / 60)}m`
                    else uptime = `${secs}s`
                } else if (uptimeRaw) {
                    uptime = String(uptimeRaw).split(' ')[0]
                }

                const activeHosts = getConnectedHosts(acsDevice)
                
                const acsBoxes = acsDevice ? `
                    <div class='grid grid-cols-4 gap-1 mt-1.5'>
                        <div class='rounded-md bg-blue-50 border border-blue-100 p-1.5 dark:bg-blue-900/20 dark:border-blue-900/30 text-center flex flex-col justify-center'>
                            <p class='text-[10px] font-black text-blue-700 dark:text-blue-400'>${redamanLive || '-'}</p>
                            <p class='text-[7px] font-black uppercase text-blue-500'>RX dB</p>
                        </div>
                        <div class='rounded-md bg-orange-50 border border-orange-100 p-1.5 dark:bg-orange-900/20 dark:border-orange-900/30 text-center flex flex-col justify-center'>
                            <p class='text-[10px] font-black text-orange-700 dark:text-orange-400'>${temp ? `${temp}°` : '-'}</p>
                            <p class='text-[7px] font-black uppercase text-orange-500'>Suhu</p>
                        </div>
                        <div class='rounded-md bg-indigo-50 border border-indigo-100 p-1.5 dark:bg-indigo-900/20 dark:border-indigo-900/30 text-center flex flex-col justify-center'>
                            <p class='text-[10px] font-black text-indigo-700 dark:text-indigo-400'>${wifiClients || '0'}</p>
                            <p class='text-[7px] font-black uppercase text-indigo-500'>Klien</p>
                        </div>
                        <div class='rounded-md bg-emerald-50 border border-emerald-100 p-1.5 dark:bg-emerald-900/20 dark:border-emerald-900/30 text-center flex flex-col justify-center'>
                            <p class='text-[10px] font-black text-emerald-700 dark:text-emerald-400'>${uptime}</p>
                            <p class='text-[7px] font-black uppercase text-emerald-500'>Uptime</p>
                        </div>
                    </div>
                    ${model ? `<p class='mt-1 text-center text-[9px] font-bold text-slate-500'>${model}</p>` : ''}
                    
                    ${activeHosts.length > 0 ? `
                    <div class='mt-2 rounded-lg bg-slate-50 dark:bg-slate-800/50 p-2'>
                        <div class='flex justify-between items-center mb-1.5'>
                            <p class='text-[8px] font-black uppercase text-slate-500'>Perangkat Terhubung</p>
                            <span class='bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-300 text-[8px] font-bold px-1.5 rounded-full'>${activeHosts.length}</span>
                        </div>
                        <div class='max-h-[85px] overflow-y-auto space-y-1 pr-1 custom-scrollbar'>
                            ${activeHosts.map((h: any) => `
                                <div class='bg-white dark:bg-slate-900 rounded p-1.5 border border-slate-100 dark:border-slate-800/60'>
                                    <p class='text-[9px] font-bold truncate text-slate-700 dark:text-slate-200'>${maskText(h.name)}</p>
                                    <div class='flex justify-between text-[8px] text-slate-400 font-mono mt-0.5'>
                                        <span>${privacyMode ? '•••.•••.•••.•••' : h.ip}</span><span>${privacyMode ? '••:••:••:••:••:••' : h.mac}</span>
                                    </div>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                    <style>
                        .custom-scrollbar::-webkit-scrollbar { width: 3px; }
                        .custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
                        .custom-scrollbar::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 4px; }
                        .dark .custom-scrollbar::-webkit-scrollbar-thumb { background: #475569; }
                    </style>
                    ` : ''}
                ` : ''

                const rawIp = user.ip_address || user.address || (acsDevice ? getNestedParam(acsDevice, 'VirtualParameters.pppoeIP') : null) || '-'
                const displayIp = privacyMode && rawIp !== '-' ? '•••.•••.•••.•••' : rawIp
                const displayAlamat = privacyMode ? 'Alamat Disembunyikan (Privacy ON)' : user.alamat

                marker.bindPopup(`
                    <div class='w-[250px] overflow-hidden rounded-xl bg-white text-slate-900 shadow-xl dark:bg-slate-900 dark:text-white'>
                        <div class='px-3 py-2.5 ${user.status === 'online' ? 'bg-emerald-600' : 'bg-slate-500'} text-white'>
                            <div class='flex items-center justify-between gap-2'>
                                <h4 class='min-w-0 truncate text-xs font-black'>${maskText(user.username)}</h4>
                                <span class='shrink-0 rounded-lg bg-white/20 px-2 py-0.5 text-[9px] font-black uppercase'>${user.status || 'unknown'}</span>
                            </div>
                        </div>
                        <div class='space-y-1.5 p-3 max-h-[260px] overflow-y-auto custom-scrollbar'>
                            <div class='grid grid-cols-2 gap-1.5'>
                                <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70'>
                                    <p class='truncate text-[11px] font-black'>${profile}</p>
                                    <p class='text-[8px] font-black uppercase text-slate-500'>Profile</p>
                                </div>
                                <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70'>
                                    <p class='live-ip truncate text-[11px] font-black'>${displayIp}</p>
                                    <p class='text-[8px] font-black uppercase text-slate-500'>IP</p>
                                </div>
                            </div>
                            
                            <div class='flex items-center justify-between rounded-lg bg-slate-900 px-3 py-1.5 text-white shadow-inner dark:bg-black'>
                                <div class='flex items-center gap-1'>
                                    <svg class='h-3 w-3 text-emerald-400' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'><path d='M12 19V5'/><path d='m5 12 7-7 7 7'/></svg>
                                    <span class='live-tx text-[10px] font-black tracking-widest text-emerald-400'>0 Kbps</span>
                                </div>
                                <div class='h-3 w-px bg-white/20'></div>
                                <div class='flex items-center gap-1'>
                                    <svg class='h-3 w-3 text-rose-400' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'><path d='M12 5v14'/><path d='m19 12-7 7-7-7'/></svg>
                                    <span class='live-rx text-[10px] font-black tracking-widest text-rose-400'>0 Kbps</span>
                                </div>
                            </div>
                            
                            ${!acsDevice && redamanAwal ? `
                            <div class='grid grid-cols-1 mt-1.5'>
                                <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70 text-center'>
                                    <p class='text-[11px] font-black text-slate-600'>${redamanAwal} dB</p>
                                    <p class='text-[8px] font-black uppercase text-slate-500'>RX Awal (Manual)</p>
                                </div>
                            </div>
                            ` : ''}

                            ${acsBoxes}

                            ${displayAlamat ? `<p class='line-clamp-2 mt-1 rounded-lg bg-slate-50 p-2 text-[9px] font-bold text-slate-500 dark:bg-slate-800/70'>${displayAlamat}</p>` : ''}
                            
                            <div class="pt-1 space-y-1">
                            ${acsDevice ? 
                                `<button onclick='window.syncAcsByUsername("${user.username}")' class='w-full rounded-lg bg-blue-600 px-2 py-2 text-[9px] font-black uppercase text-white hover:bg-blue-700 transition-colors shadow-sm'>Refresh Data</button>` : 
                                `<p class='text-center text-[9px] italic text-slate-400'>Perangkat tidak terdeteksi di ACS</p>`
                            }
                            <a href='/customers?search=${user.username}' target='_blank' class='block rounded-lg border border-slate-200 dark:border-slate-700 px-2 py-2 text-center text-[9px] font-black uppercase text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors'>Buka Detail Pelanggan →</a>
                            </div>
                        </div>
                    </div>
                `, { className: 'premium-popup', closeButton: false, autoPan: true, autoPanPadding: [24, 24], maxWidth: 260 })
                
                marker.on('popupopen', async (e: any) => {
                    const popupNode = e.popup.getElement()
                    if (!popupNode) return
                    
                    const ipEl = popupNode.querySelector('.live-ip')
                    const rxEl = popupNode.querySelector('.live-rx')
                    const txEl = popupNode.querySelector('.live-tx')
                    
                    try {
                        if (rxEl) rxEl.innerText = '...'
                        if (txEl) txEl.innerText = '...'
                        
                        const res = await api.post('/mikrotik_action.php', {
                            router_id: activeRouter?.id,
                            action: 'user_status',
                            params: { username: user.username }
                        })
                        const data = res.data.data
                        if (ipEl && data.ip && data.ip !== '-') ipEl.innerText = data.ip
                        if (rxEl) rxEl.innerText = formatBps(data.tx_bps)
                        if (txEl) txEl.innerText = formatBps(data.rx_bps)
                    } catch(err) {
                        console.error("Gagal mengambil data live MikroTik:", err)
                        if (rxEl && rxEl.innerText === '...') rxEl.innerText = '0 Kbps'
                        if (txEl && txEl.innerText === '...') txEl.innerText = '0 Kbps'
                    }
                })

                clusterGroup.addLayer(marker)
                markerInstancesRef.current.users[String(user.username).toLowerCase()] = marker
                bounds.extend(pos)
                hasPoints = true
            }
        })
    }

    // 3.5. Automatic Cables (Router -> ODC -> ODP)
    // A. Backbone Cables
    if (layers.cablesBackbone && rLat !== 0 && rLng !== 0) {
        const rPos: [number, number] = [rLat, rLng]

        // 1. Router -> ODC Cables
        if (odcList && layers.odcs) {
            odcList.forEach((odc: any) => {
                if (isValidCoordinate(odc.lat, odc.lng)) {
                    const odcPos: [number, number] = [parseFloat(odc.lat), parseFloat(odc.lng)]
                    const backboneLine = L.polyline([rPos, odcPos], {
                        color: '#f59e0b', // Amber untuk Router -> ODC
                        weight: 6.5,
                        opacity: 0.95,
                        className: 'backbone-flow'
                    }).addTo(mapInstance)
                    backboneLine.bindTooltip(`Router → ${odc.name} (Backbone ODC)`, { direction: 'center', sticky: true, opacity: 0.9 })
                    elementsRef.current.push(backboneLine)
                }
            })
        }

        // 2. Upstream -> ODP Cables
        if (odpList && layers.odps) {
            odpList.forEach((odp: any) => {
                if (isValidCoordinate(odp.lat, odp.lng)) {
                    const odpPos: [number, number] = [parseFloat(odp.lat), parseFloat(odp.lng)]
                    
                    // Tentukan titik awal penarikan kabel backbone (Router, ODC, atau ODP Hulu)
                    let startPos = rPos
                    let startName = 'Router'
                    let color = '#6366f1' // Indigo default untuk Router -> ODP
                    
                    if (odp.parent_id) {
                        const parentOdp = odpList.find((o: any) => String(o.id) === String(odp.parent_id))
                        if (parentOdp && isValidCoordinate(parentOdp.lat, parentOdp.lng)) {
                            startPos = [parseFloat(parentOdp.lat), parseFloat(parentOdp.lng)]
                            startName = parentOdp.name
                            color = '#3b82f6' // Blue untuk ODP -> ODP (Cascading)
                        }
                    } else if (odp.odc_id) {
                        const parentOdc = odcList?.find((o: any) => String(o.id) === String(odp.odc_id))
                        if (parentOdc && isValidCoordinate(parentOdc.lat, parentOdc.lng)) {
                            startPos = [parseFloat(parentOdc.lat), parseFloat(parentOdc.lng)]
                            startName = parentOdc.name
                            color = '#d97706' // Darker Amber untuk ODC -> ODP
                        }
                    }
                    
                    const customLine = linesList?.find((l: any) => l.type === 'backbone' && l.name === `backbone_odp_${odp.id}`)
                    const pathCoordinates = customLine && customLine.path && customLine.path.length >= 2 
                        ? customLine.path.map((pt: any) => [pt.lat ?? pt[0], pt.lng ?? pt[1]])
                        : [startPos, odpPos];

                    const backboneLine = L.polyline(pathCoordinates, {
                        color,
                        weight: 6,
                        opacity: 0.9,
                        className: 'backbone-flow cursor-pointer'
                    }).addTo(mapInstance)
                    
                    backboneLine.bindTooltip(`
                        <div class="px-2 py-1 text-[10px] font-bold text-slate-800 dark:text-slate-100">
                            <div class="text-[9px] font-black uppercase text-indigo-600 dark:text-indigo-400 mb-0.5">${startName} → ${odp.name}</div>
                            <div>Panjang: ${formatDistance(calculateLineDistance(pathCoordinates))}</div>
                        </div>
                    `, { direction: 'center', sticky: true, opacity: 0.95 })

                    backboneLine.on('mousemove', (e: any) => {
                        const distAlong = calculateDistanceAlongPath(pathCoordinates, e.latlng)
                        const totalDist = calculateLineDistance(pathCoordinates)
                        const percent = totalDist > 0 ? ((distAlong / totalDist) * 100).toFixed(0) : '0'
                        
                        backboneLine.setTooltipContent(`
                            <div class="px-2 py-1 text-[10px] font-bold text-slate-800 dark:text-slate-100 leading-normal">
                                <div class="text-[9px] font-black uppercase text-indigo-600 dark:text-indigo-400 mb-0.5">${startName} → ${odp.name}</div>
                                <div>Hingga Kursor: <span class="text-indigo-600 dark:text-indigo-400 font-black">${formatDistance(distAlong)}</span> (${percent}%)</div>
                                <div class="text-[8px] opacity-70 border-t border-slate-100 dark:border-slate-800 mt-1 pt-0.5">Panjang Total: ${formatDistance(totalDist)}</div>
                            </div>
                        `)
                    })
                    
                    backboneLine.bindPopup(`
                        <div class='w-[190px] overflow-hidden rounded-xl bg-white text-slate-900 shadow-xl dark:bg-slate-900 dark:text-white'>
                            <div class='px-3 py-2 bg-indigo-600 text-white flex items-center justify-between'>
                                <span class='text-xs font-black truncate'>Kabel Backbone</span>
                                <span class='shrink-0 rounded-lg bg-white/20 px-1.5 py-0.5 text-[8px] font-black uppercase'>ODP</span>
                            </div>
                            <div class='p-3 space-y-1.5'>
                                <p class='text-[10px] font-bold text-slate-700 dark:text-slate-300 truncate'>${startName} → ${odp.name}</p>
                                <p class='text-[9px] text-slate-500'>Panjang: ${formatDistance(calculateLineDistance(pathCoordinates))}</p>
                                <button onclick='window.startEditCable("backbone", "${odp.id}", "${startName} → ${odp.name}")' class='w-full rounded-lg border border-indigo-200 text-indigo-600 px-2 py-2 text-[9px] font-black uppercase hover:bg-indigo-50 transition-colors flex items-center justify-center gap-1' style='color: #4f46e5 !important; background: transparent;'>
                                    🔧 Edit Jalur Kabel
                                </button>
                            </div>
                        </div>
                    `, { className: 'premium-popup', closeButton: false, autoPan: true, maxWidth: 200 })
                    
                    elementsRef.current.push(backboneLine)
                }
            })
        }
    }

    // B. ODP -> User
    if (layers.cablesCustomer && usersList) {
        usersList
          .filter((user: any) => statusFilter === 'all' || user.status === statusFilter)
          .forEach((user: any) => {
            if (user.odp_id && isValidCoordinate(user.lat, user.lng)) {
                const odp = odpList?.find((o: any) => String(o.id) === String(user.odp_id))
                if (odp && isValidCoordinate(odp.lat, odp.lng)) {
                    const isOnline = user.status === 'online'
                    const userPos: [number, number] = [parseFloat(user.lat), parseFloat(user.lng)]
                    const customLine = linesList?.find((l: any) => l.type === 'customer' && l.name === `customer_user_${user.username}`)
                    const pathCoordinates = customLine && customLine.path && customLine.path.length >= 2 
                        ? customLine.path.map((pt: any) => [pt.lat ?? pt[0], pt.lng ?? pt[1]])
                        : [[parseFloat(odp.lat), parseFloat(odp.lng)], userPos];

                    const line = L.polyline(pathCoordinates, {
                        color: isOnline ? '#22c55e' : '#ef4444',
                        weight: isOnline ? 5.5 : 5,
                        opacity: isOnline ? 0.88 : 0.78,
                        dashArray: isOnline ? '16, 12' : '10, 12',
                        lineCap: 'round',
                        lineJoin: 'round',
                        className: `cable-flow ${isOnline ? 'online' : 'offline'} cursor-pointer`
                    }).addTo(mapInstance)
                    
                    line.bindTooltip(`
                        <div class="px-2 py-1 text-[10px] font-bold text-slate-800 dark:text-slate-100">
                            <div class="text-[9px] font-black uppercase text-emerald-600 dark:text-emerald-400 mb-0.5">${maskText(user.username)} (${odp.name})</div>
                            <div>Panjang: ${formatDistance(calculateLineDistance(pathCoordinates))}</div>
                        </div>
                    `, { direction: 'center', sticky: true, opacity: 0.95 })

                    line.on('mousemove', (e: any) => {
                        const distAlong = calculateDistanceAlongPath(pathCoordinates, e.latlng)
                        const totalDist = calculateLineDistance(pathCoordinates)
                        const percent = totalDist > 0 ? ((distAlong / totalDist) * 100).toFixed(0) : '0'
                        
                        line.setTooltipContent(`
                            <div class="px-2 py-1 text-[10px] font-bold text-slate-800 dark:text-slate-100 leading-normal">
                                <div class="text-[9px] font-black uppercase text-emerald-600 dark:text-emerald-400 mb-0.5">${maskText(user.username)} (${odp.name})</div>
                                <div>Hingga Kursor: <span class="text-emerald-600 dark:text-emerald-400 font-black">${formatDistance(distAlong)}</span> (${percent}%)</div>
                                <div class="text-[8px] opacity-70 border-t border-slate-100 dark:border-slate-800 mt-1 pt-0.5">Panjang Total: ${formatDistance(totalDist)}</div>
                            </div>
                        `)
                    })
                    
                    line.bindPopup(`
                        <div class='w-[190px] overflow-hidden rounded-xl bg-white text-slate-900 shadow-xl dark:bg-slate-900 dark:text-white'>
                            <div class='px-3 py-2 bg-emerald-600 text-white flex items-center justify-between'>
                                <span class='text-xs font-black truncate'>Kabel Distribusi</span>
                                <span class='shrink-0 rounded-lg bg-white/20 px-1.5 py-0.5 text-[8px] font-black uppercase'>Klien</span>
                            </div>
                            <div class='p-3 space-y-1.5'>
                                <p class='text-[10px] font-bold text-slate-700 dark:text-slate-300 truncate'>${maskText(user.username)} (${odp.name})</p>
                                <p class='text-[9px] text-slate-500'>Panjang: ${formatDistance(calculateLineDistance(pathCoordinates))}</p>
                                <button onclick='window.startEditCable("customer", "${user.username}", "${user.username}")' class='w-full rounded-lg border border-emerald-200 text-emerald-600 px-2 py-2 text-[9px] font-black uppercase hover:bg-emerald-50 transition-colors flex items-center justify-center gap-1' style='color: #059669 !important; background: transparent;'>
                                    🔧 Edit Jalur Kabel
                                </button>
                            </div>
                        </div>
                    `, { className: 'premium-popup', closeButton: false, autoPan: true, maxWidth: 200 })
                    
                    elementsRef.current.push(line)
                }
            }
        })
    }

    // 4. Lines
    if (linesList && layers.lines) {
        linesList
            .filter((line: any) => line.type === 'manual' || !line.type)
            .forEach((line: any) => {
            if (line.path && line.path.length > 0) {
                const poly = L.polyline(line.path, { color: line.color || '#3b82f6', weight: 3, opacity: 0.8 }).addTo(mapInstance)
                poly.bindPopup(`
                    <div class='w-[200px] overflow-hidden rounded-xl bg-white text-slate-900 shadow-xl dark:bg-slate-900 dark:text-white'>
                        <div class='px-3 py-2 bg-blue-600 text-white flex items-center justify-between'>
                            <span class='text-xs font-black truncate'>${line.name || 'Jalur Kabel'}</span>
                            <span class='shrink-0 rounded-lg bg-white/20 px-2 py-0.5 text-[9px] font-black uppercase'>Manual</span>
                        </div>
                        <div class='p-3 space-y-2'>
                            <div class='grid grid-cols-2 gap-1.5'>
                                <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70 text-center'>
                                    <p class='text-[11px] font-black text-blue-600 dark:text-blue-400'>${formatDistance(calculateLineDistance(line.path))}</p>
                                    <p class='text-[8px] font-black uppercase text-slate-500'>Panjang</p>
                                </div>
                                <div class='rounded-lg bg-slate-50 p-2 dark:bg-slate-800/70 text-center'>
                                    <p class='text-[11px] font-black'>${line.path.length}</p>
                                    <p class='text-[8px] font-black uppercase text-slate-500'>Titik</p>
                                </div>
                            </div>
                            <button onclick='window.deleteNetworkLine(${line.id})' class='w-full rounded-lg bg-red-50 border border-red-200 text-red-600 px-2 py-2 text-[9px] font-black uppercase hover:bg-red-100 transition-colors flex items-center justify-center gap-1'>
                                🗑 Hapus Jalur Ini
                            </button>
                        </div>
                    </div>
                `, { className: 'premium-popup', closeButton: false, autoPan: true, maxWidth: 210 })
                elementsRef.current.push(poly)
                line.path.forEach((p: any) => bounds.extend(p))
                hasPoints = true
            }
        })
    }
    if (hasPoints && mapInstance && lastFittedId.current !== activeRouter?.id) {
        mapInstance.fitBounds(bounds, { padding: [100, 100], maxZoom: 20 })
        lastFittedId.current = activeRouter?.id || null
    }
  // Note: routerSummary intentionally excluded - router popup is updated in a separate effect below
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mapInstance, clusterGroup, odcList, odpList, usersList, linesList, activeRouter, layers, statusFilter, acsDevices, privacyMode])

  // Register global function for Leaflet popups (with proper cleanup to avoid memory leak)
  useEffect(() => {
    (window as any).syncAcsByUsername = async (username: string) => {
      const acsDevice = acsDevices?.find((d: any) => getNestedParam(d, 'VirtualParameters.pppoeUsername') === username)
      if (acsDevice && acsDevice._id) {
         toast.loading('Menyinkronkan data dengan modem...', { id: 'acs-sync' })
         try {
             await api.post(`/genieacs_proxy.php?path=/devices/${acsDevice._id}/tasks?timeout=3000&connection_request`, { name: 'refreshObject', objectName: '' })
             toast.success('Perintah sinkronisasi berhasil dikirim', { id: 'acs-sync' })
             setTimeout(() => {
                 queryClient.invalidateQueries({ queryKey: ['genieacs-devices'] })
             }, 2000)
         } catch(err) {
             toast.error('Gagal menyinkronkan data ACS', { id: 'acs-sync' })
         }
      } else {
         toast.error('Perangkat belum terhubung ke ACS')
      }
    }

    ;(window as any).deleteNetworkLine = async (lineId: number) => {
      if (!lineId) return
      toast.loading('Menghapus jalur...', { id: 'delete-line' })
      try {
        await api.delete('/network_lines.php', { params: { id: lineId } })
        toast.success('Jalur kabel dihapus', { id: 'delete-line' })
        queryClient.invalidateQueries({ queryKey: ['network-lines'] })
      } catch (err) {
        toast.error('Gagal menghapus jalur', { id: 'delete-line' })
      }
    }

    ;(window as any).startEditCable = (type: 'backbone' | 'customer', targetId: string, displayName: string) => {
      if (mapInstance) {
          mapInstance.closePopup()
      }
      
      let originalPath: [number, number][] = []
      let id: number | undefined
      
      const rLat = activeRouter?.lat ? parseFloat(activeRouter.lat) : -6.9
      const rLng = activeRouter?.lng ? parseFloat(activeRouter.lng) : 109.6
      const routerPos: [number, number] = [rLat, rLng]

      if (type === 'backbone') {
          const odp = odpList?.find((o: any) => String(o.id) === String(targetId))
          if (odp) {
              const odpPos: [number, number] = [parseFloat(odp.lat), parseFloat(odp.lng)]
              let startPos = routerPos
              if (odp.parent_id) {
                  const parentOdp = odpList.find((o: any) => String(o.id) === String(odp.parent_id))
                  if (parentOdp) startPos = [parseFloat(parentOdp.lat), parseFloat(parentOdp.lng)]
              } else if (odp.odc_id) {
                  const parentOdc = odcList?.find((o: any) => String(o.id) === String(odp.odc_id))
                  if (parentOdc) startPos = [parseFloat(parentOdc.lat), parseFloat(parentOdc.lng)]
              }
              originalPath = [startPos, odpPos]
              
              const customLine = linesList?.find((l: any) => l.type === 'backbone' && l.name === `backbone_odp_${targetId}`)
              if (customLine) {
                  id = customLine.id
                  originalPath = customLine.path.map((pt: any) => [pt.lat ?? pt[0], pt.lng ?? pt[1]])
              }
          }
      } else {
          const user = usersList?.find((u: any) => String(u.username) === String(targetId))
          if (user) {
              const userPos: [number, number] = [parseFloat(user.lat), parseFloat(user.lng)]
              let startPos = routerPos
              const odp = odpList?.find((o: any) => String(o.id) === String(user.odp_id))
              if (odp) startPos = [parseFloat(odp.lat), parseFloat(odp.lng)]
              originalPath = [startPos, userPos]
              
              const customLine = linesList?.find((l: any) => l.type === 'customer' && l.name === `customer_user_${targetId}`)
              if (customLine) {
                  id = customLine.id
                  originalPath = customLine.path.map((pt: any) => [pt.lat ?? pt[0], pt.lng ?? pt[1]])
              }
          }
      }
      
      if (originalPath.length >= 2) {
          setEditingCable({
              type,
              targetId,
              displayName,
              path: JSON.parse(JSON.stringify(originalPath)),
              originalPath: JSON.parse(JSON.stringify(originalPath)),
              id
          })
          toast.info(`Memulai edit jalur kabel: ${displayName}`, { id: 'edit-mode-started' })
      } else {
          toast.error('Gagal menemukan koordinat awal kabel')
      }
    }

    return () => {
      delete (window as any).syncAcsByUsername
      delete (window as any).deleteNetworkLine
      delete (window as any).startEditCable
    }
  }, [acsDevices, queryClient, mapInstance, odpList, odcList, usersList, linesList, activeRouter])

  // Effect for rendering and managing active cable editor markers and polyline
  useEffect(() => {
    if (!mapInstance || !editingCable) {
        editMarkersRef.current.forEach(m => m.remove())
        editMarkersRef.current = []
        if (editPolylineRef.current) {
            editPolylineRef.current.remove()
            editPolylineRef.current = null
        }
        return
    }

    // Bersihkan marker edit sebelumnya
    editMarkersRef.current.forEach(m => m.remove())
    editMarkersRef.current = []
    if (editPolylineRef.current) {
        editPolylineRef.current.remove()
    }

    const { path } = editingCable

    // 1. Gambar Polyline Kuning Beranimasi
    const poly = L.polyline(path, {
        color: '#eab308', // Yellow-500
        weight: 5,
        opacity: 0.9,
        dashArray: '8, 8',
        className: 'cable-edit-flow'
    }).addTo(mapInstance)
    editPolylineRef.current = poly

    // Tambahkan CSS custom keyframe animasinya ke header jika belum ada
    if (!document.getElementById('cable-edit-animation-css')) {
        const style = document.createElement('style')
        style.id = 'cable-edit-animation-css'
        style.innerHTML = `
          .leaflet-overlay-pane path.cable-edit-flow {
            animation: cable-edit-animation 0.8s linear infinite !important;
          }
          @keyframes cable-edit-animation {
            to { stroke-dashoffset: -16; }
          }
        `
        document.head.appendChild(style)
    }

    // 2. Render Ujung & Belokan Tengah (Draggable Markers)
    path.forEach((coords, index) => {
        const isEndpoint = index === 0 || index === path.length - 1
        
        const icon = L.divIcon({
            className: 'custom-edit-marker',
            html: isEndpoint 
                ? `<div class="h-3 w-3 rounded-full border-2 border-blue-600 bg-blue-100 shadow-md" title="Ujung kabel (statis)"></div>`
                : `<div class="h-3 w-3 rounded-full border-2 border-indigo-600 bg-white shadow-md cursor-move hover:scale-125 transition-transform" title="Geser belokan (Klik kanan untuk hapus)"></div>`,
            iconSize: [12, 12],
            iconAnchor: [6, 6]
        })

        const marker = L.marker(coords, {
            icon,
            draggable: !isEndpoint
        }).addTo(mapInstance)

        if (!isEndpoint) {
            marker.on('drag', (e: any) => {
                const newLatLng = e.target.getLatLng()
                if (editPolylineRef.current) {
                    const tempPath = [...path]
                    tempPath[index] = [newLatLng.lat, newLatLng.lng]
                    editPolylineRef.current.setLatLngs(tempPath)
                }
            })

            marker.on('dragend', (e: any) => {
                const newLatLng = e.target.getLatLng()
                setEditingCable(prev => {
                    if (!prev) return null
                    const newPath = [...prev.path]
                    newPath[index] = [newLatLng.lat, newLatLng.lng]
                    return { ...prev, path: newPath }
                })
            })

            marker.on('contextmenu', () => {
                setEditingCable(prev => {
                    if (!prev) return null
                    if (prev.path.length <= 2) {
                        toast.error('Jalur harus memiliki minimal 2 titik')
                        return prev
                    }
                    const newPath = prev.path.filter((_, i) => i !== index)
                    toast.success('Titik belokan dihapus')
                    return { ...prev, path: newPath }
                })
            })
        }

        editMarkersRef.current.push(marker)
    })

    // 3. Render Midpoint Markers (Titik Kuning Kecil untuk Disisipkan)
    for (let i = 0; i < path.length - 1; i++) {
        const midLat = (path[i][0] + path[i+1][0]) / 2
        const midLng = (path[i][1] + path[i+1][1]) / 2
        const midPos: [number, number] = [midLat, midLng]

        const midIcon = L.divIcon({
            className: 'custom-mid-marker',
            html: `<div class="h-2.5 w-2.5 rounded-full border border-amber-500 bg-yellow-400/80 shadow-xs cursor-crosshair hover:scale-125 transition-transform" title="Tarik untuk buat belokan baru"></div>`,
            iconSize: [10, 10],
            iconAnchor: [5, 5]
        })

        const midMarker = L.marker(midPos, {
            icon: midIcon,
            draggable: true
        }).addTo(mapInstance)

        midMarker.on('drag', (e: any) => {
            const newLatLng = e.target.getLatLng()
            if (editPolylineRef.current) {
                const tempPath = [...path]
                tempPath.splice(i + 1, 0, [newLatLng.lat, newLatLng.lng])
                editPolylineRef.current.setLatLngs(tempPath)
            }
        })

        midMarker.on('dragend', (e: any) => {
            const newLatLng = e.target.getLatLng()
            setEditingCable(prev => {
                if (!prev) return null
                const newPath = [...prev.path]
                newPath.splice(i + 1, 0, [newLatLng.lat, newLatLng.lng])
                toast.success('Titik belokan baru ditambahkan')
                return { ...prev, path: newPath }
            })
        })

        editMarkersRef.current.push(midMarker)
    }

  }, [mapInstance, editingCable])

  // Separate effect: Update router popup live data (every 2 seconds) without rebuilding all markers
  useEffect(() => {
    if (!mapInstance) return
    const routerMarker = (elementsRef.current as any[]).find(el => el._isRouter)
    if (!routerMarker || !routerSummary) return

    const res = routerSummary?.resource
    const identity = routerSummary?.identity || 'SERVER UTAMA'
    const topIf = routerSummary?.top_interface
    const internet = routerSummary?.internet || 'Error'
    const cpu = res?.['cpu-load'] !== undefined ? `${res['cpu-load']}%` : '...'
    const uptime = res?.uptime || '...'
    const model = res?.['board-name'] || '...'

    const popupContent = `
        <div class='w-[230px] overflow-hidden rounded-xl bg-[#1e293b]/95 text-white shadow-xl'>
            <div class='flex items-center justify-between gap-2 border-b border-white/10 bg-blue-600/30 px-3 py-2.5'>
                <b class='min-w-0 truncate text-xs font-black uppercase'>${identity}</b>
                <span class='shrink-0 rounded-lg bg-white/15 px-2 py-0.5 text-[9px] font-black uppercase'>Online</span>
            </div>
            <div class='space-y-2 p-3'>
                <div class='flex items-center justify-between gap-2 rounded-lg bg-black/25 p-2'>
                    <span class='text-[9px] font-black uppercase text-slate-400'>Model</span>
                    <span class='truncate text-[10px] font-black text-slate-200'>${model}</span>
                </div>
                <div class='flex items-center justify-between'>
                    <span class='text-[11px] font-bold text-slate-400'>CPU</span>
                    <span class='text-[11px] font-black text-green-400'>${cpu}</span>
                </div>
                <div class='flex items-center justify-between'>
                    <span class='text-[11px] font-bold text-slate-400'>Uptime</span>
                    <span class='text-[11px] font-black text-orange-400'>${uptime}</span>
                </div>
                <div class='flex items-center justify-between'>
                    <span class='text-[11px] font-bold text-slate-400'>Internet (8.8.8.8)</span>
                    <span class='text-[11px] font-black ${internet === 'OK' ? 'text-green-400' : 'text-red-500'}'>${internet}</span>
                </div>
                ${topIf ? `
                <div class='space-y-2 rounded-lg bg-black/30 p-2'>
                    <div class='text-[9px] font-black uppercase text-cyan-400 tracking-widest'>TRAFFIC ${topIf.name}</div>
                    <div class='flex justify-between'>
                        <span class='text-[13px] font-black text-green-400'>↓ ${formatBps(topIf.bps_rx)}</span>
                        <span class='text-[13px] font-black text-blue-400'>↑ ${formatBps(topIf.bps_tx)}</span>
                    </div>
                </div>` : ''}
            </div>
        </div>
    `
    if (routerMarker.isPopupOpen()) {
      routerMarker.setPopupContent(popupContent)
    } else {
      routerMarker.bindPopup(popupContent, {
        className: 'premium-popup',
        autoPan: true,
        autoPanPadding: [24, 24],
        closeButton: false,
        maxWidth: 250
      })
    }
  }, [mapInstance, routerSummary])

  const getSuggestions = () => {
    if (!searchQuery || searchQuery.trim().length < 2) return []
    const q = searchQuery.toLowerCase()
    const results: Array<{ id: string; name: string; type: 'user' | 'odp' | 'odc'; sub: string; lat: string; lng: string }> = []

    // 1. Pelanggan
    if (usersList) {
        usersList.forEach((u: any) => {
            if (
                u.username.toLowerCase().includes(q) || 
                (u.nama && u.nama.toLowerCase().includes(q)) || 
                (u.alamat && u.alamat.toLowerCase().includes(q)) || 
                (u.location && u.location.toLowerCase().includes(q))
            ) {
                results.push({
                    id: u.username,
                    name: u.username,
                    type: 'user',
                    sub: u.nama ? `Pelanggan • ${u.nama}` : 'Pelanggan',
                    lat: u.lat,
                    lng: u.lng
                })
            }
        })
    }

    // 2. ODP
    if (odpList) {
        odpList.forEach((o: any) => {
            if (
                o.name?.toLowerCase().includes(q) || 
                (o.location && o.location.toLowerCase().includes(q))
            ) {
                results.push({
                    id: String(o.id),
                    name: o.name,
                    type: 'odp',
                    sub: `ODP • ${o.location || 'Tanpa Lokasi'}`,
                    lat: o.lat,
                    lng: o.lng
                })
            }
        })
    }

    // 3. ODC
    if (odcList) {
        odcList.forEach((o: any) => {
            if (
                o.name?.toLowerCase().includes(q) || 
                (o.location && o.location.toLowerCase().includes(q))
            ) {
                results.push({
                    id: String(o.id),
                    name: o.name,
                    type: 'odc',
                    sub: `ODC • ${o.capacity || 12} Port`,
                    lat: o.lat,
                    lng: o.lng
                })
            }
        })
    }

    return results.slice(0, 25)
  }

  const handleSelectSuggestion = (item: { id: string; name: string; type: 'user' | 'odp' | 'odc'; lat: string; lng: string }) => {
    setSearchQuery(item.name)
    setShowSuggestions(false)

    if (!mapInstance || !isValidCoordinate(item.lat, item.lng)) {
        toast.error('Koordinat tidak valid')
        return
    }

    let marker: any = null
    let zoomLevel = 18

    if (item.type === 'user') {
        marker = markerInstancesRef.current.users[item.id.toLowerCase()]
        zoomLevel = 21
    } else if (item.type === 'odp') {
        marker = markerInstancesRef.current.odps[item.id]
        zoomLevel = 20
    } else if (item.type === 'odc') {
        marker = markerInstancesRef.current.odcs[item.id]
        zoomLevel = 18
    }

    if (marker && clusterGroup) {
        clusterGroup.zoomToShowLayer(marker, () => {
            setTimeout(() => marker.openPopup(), 100)
        })
    } else {
        mapInstance.flyTo([parseFloat(item.lat), parseFloat(item.lng)], zoomLevel, { duration: 1.5 })
    }

    const typeLabels = { user: 'Pelanggan', odp: 'ODP', odc: 'ODC' }
    toast.success(`${typeLabels[item.type]}: ${item.name}`)
  }

  const handleSearch = () => {
    if (!searchQuery || !mapInstance) return
    const q = searchQuery.toLowerCase()

    // Priority 1: Search users
    const user = usersList?.find((u: any) => 
        u.username.toLowerCase().includes(q) || 
        (u.nama && u.nama.toLowerCase().includes(q)) || 
        (u.alamat && u.alamat.toLowerCase().includes(q)) || 
        (u.location && u.location.toLowerCase().includes(q))
    )
    if (user && isValidCoordinate(user.lat, user.lng)) {
        const marker = markerInstancesRef.current.users[user.username.toLowerCase()]
        if (marker && clusterGroup) {
            clusterGroup.zoomToShowLayer(marker, () => {
                setTimeout(() => marker.openPopup(), 100)
            })
        } else {
            mapInstance.flyTo([parseFloat(user.lat), parseFloat(user.lng)], 21, { duration: 1.5 })
        }
        toast.success(`Pelanggan: ${user.username}`)
        return
    }

    // Priority 2: Search ODP
    const odp = odpList?.find((o: any) => 
        o.name?.toLowerCase().includes(q) || 
        (o.location && o.location.toLowerCase().includes(q))
    )
    if (odp && isValidCoordinate(odp.lat, odp.lng)) {
        const marker = markerInstancesRef.current.odps[String(odp.id)]
        if (marker && clusterGroup) {
            clusterGroup.zoomToShowLayer(marker, () => {
                setTimeout(() => marker.openPopup(), 100)
            })
        } else {
            mapInstance.flyTo([parseFloat(odp.lat), parseFloat(odp.lng)], 20, { duration: 1.5 })
        }
        toast.success(`ODP: ${odp.name}`)
        return
    }

    // Priority 3: Search ODC
    const odc = odcList?.find((o: any) => 
        o.name?.toLowerCase().includes(q) || 
        (o.location && o.location.toLowerCase().includes(q))
    )
    if (odc && isValidCoordinate(odc.lat, odc.lng)) {
        const marker = markerInstancesRef.current.odcs[String(odc.id)]
        if (marker && clusterGroup) {
            clusterGroup.zoomToShowLayer(marker, () => {
                setTimeout(() => marker.openPopup(), 100)
            })
        } else {
            mapInstance.flyTo([parseFloat(odc.lat), parseFloat(odc.lng)], 18, { duration: 1.5 })
        }
        toast.success(`ODC: ${odc.name}`)
        return
    }

    toast.error('Tidak ditemukan: pelanggan, ODP, atau ODC')
  }

  const toggleLayer = (key: keyof typeof layers) => {
    setLayers(prev => ({ ...prev, [key]: !prev[key] }))
  }

  const fitAllPoints = () => {
    if (!mapInstance) return
    const bounds = L.latLngBounds([])
    let hasPoints = false
    if (isValidCoordinate(activeRouter?.lat, activeRouter?.lng)) {
      bounds.extend([Number(activeRouter?.lat), Number(activeRouter?.lng)])
      hasPoints = true
    }
    odpList?.forEach((o: any) => {
      if (isValidCoordinate(o.lat, o.lng)) {
        bounds.extend([parseFloat(o.lat), parseFloat(o.lng)])
        hasPoints = true
      }
    })
    usersList?.forEach((u: any) => {
      if (isValidCoordinate(u.lat, u.lng)) {
        bounds.extend([parseFloat(u.lat), parseFloat(u.lng)])
        hasPoints = true
      }
    })
    if (hasPoints) mapInstance.fitBounds(bounds, { padding: [100, 100], maxZoom: 20 })
  }

  const goToRouter = () => {
    if (mapInstance && isValidCoordinate(activeRouter?.lat, activeRouter?.lng)) {
      mapInstance.flyTo([Number(activeRouter?.lat), Number(activeRouter?.lng)], 21, { duration: 1.5 })
    }
  }

  const saveLine = async () => {
    if (!permissions.canManageCustomers) {
        toast.error('Anda tidak punya akses mengubah network map')
        return
    }
    if (drawPoints.length < 2) {
        toast.error('Gambarkan minimal 2 titik')
        return
    }
    const autoName = `Kabel-${new Date().toLocaleDateString('id-ID', { day: '2-digit', month: '2-digit' })}-${new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }).replace(':', '')}`
    const name = autoName

    try {
        await api.post('/network_lines.php', {
            router_id: activeRouter?.software_id || activeRouter?.id,
            name,
            type: 'manual',
            path: drawPoints,
            color: '#3b82f6'
        })
        toast.success('Jalur kabel disimpan')
        setIsDrawing(false)
        setDrawPoints([])
        queryClient.invalidateQueries({ queryKey: ['network-lines'] })
    } catch (err) {
        toast.error('Gagal menyimpan jalur')
    }
  }



  // Register global function for Leaflet popups
  return (
    <>
      <Header fixed className='z-2000'>
        <div className='me-auto flex items-center gap-2'>
          <div className='p-2 bg-indigo-100 dark:bg-indigo-900/30 rounded-lg'>
            <MapIcon className='h-5 w-5 text-indigo-600' />
          </div>
          <h1 className='text-lg font-bold'>Network Topology Map</h1>
        </div>
        <RouterSelector />
        <ThemeSwitch />
        <ProfileDropdown />
      </Header>

      <Main className='p-0 flex flex-col h-[calc(100vh-64px)] overflow-hidden' fluid>
        <div className='flex-1 relative overflow-hidden bg-slate-950'>
            <div className='absolute inset-0 z-0 bg-[radial-gradient(circle_at_top_left,rgba(59,130,246,0.18),transparent_30%),radial-gradient(circle_at_bottom_right,rgba(16,185,129,0.16),transparent_30%)]' />
            <div ref={mapRef} className='absolute inset-0 z-0 [&_.leaflet-control-attribution]:hidden [&_.leaflet-control-zoom]:rounded-2xl [&_.leaflet-control-zoom]:overflow-hidden [&_.leaflet-control-zoom]:border-0 [&_.leaflet-control-zoom]:shadow-2xl' />
            <div className='pointer-events-none absolute inset-x-0 top-0 z-500 h-32 bg-linear-to-b from-slate-950/35 to-transparent' />
            <div className='pointer-events-none absolute inset-x-0 bottom-0 z-500 h-40 bg-linear-to-t from-slate-950/35 to-transparent' />

            {/* No Router Selected Overlay */}
            {!activeRouter && (
                <div className='absolute inset-0 z-2000 flex flex-col items-center justify-center bg-slate-950/80 backdrop-blur-sm'>
                    <div className='flex flex-col items-center gap-4 rounded-2xl border border-white/10 bg-slate-900/90 px-10 py-8 shadow-2xl text-center'>
                        <div className='p-4 bg-indigo-500/20 rounded-2xl'>
                            <MapIcon className='h-10 w-10 text-indigo-400' />
                        </div>
                        <div>
                            <p className='text-sm font-black uppercase tracking-widest text-white'>Belum Ada Router Dipilih</p>
                            <p className='mt-1.5 text-[11px] text-slate-400 max-w-[220px]'>Pilih router dari dropdown di atas untuk menampilkan peta jaringan</p>
                        </div>
                    </div>
                </div>
            )}
            
            <div className='absolute left-6 right-6 top-6 z-1500 flex flex-col gap-3 xl:flex-row xl:items-start xl:justify-between'>
              <div ref={searchContainerRef} className='relative w-full max-w-md flex gap-2'>
                <div className='relative flex-1 group'>
                    <Search className='absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground group-focus-within:text-primary transition-colors' />
                    <Input 
                        placeholder='Cari Pelanggan / ODP / ODC...' 
                        className='pl-10 h-12 bg-white/95 dark:bg-slate-900/95 backdrop-blur-xl shadow-2xl border border-white/30 dark:border-white/10 font-bold rounded-2xl'
                        value={searchQuery}
                        onFocus={() => setShowSuggestions(true)}
                        onChange={e => {
                            setSearchQuery(e.target.value)
                            setShowSuggestions(true)
                        }}
                        onKeyDown={e => e.key === 'Enter' && handleSearch()}
                    />

                    {/* Panel Sugesti */}
                    {showSuggestions && getSuggestions().length > 0 && (
                        <div className='absolute left-0 right-0 top-14 z-99999 overflow-hidden rounded-2xl border border-border bg-white/95 shadow-2xl backdrop-blur-2xl dark:border-white/10 dark:bg-slate-900/95 p-1 max-h-[300px] overflow-y-auto'>
                            {getSuggestions().map((item, index) => {
                                let IconComp = Users
                                if (item.type === 'odp') IconComp = Box
                                if (item.type === 'odc') IconComp = Server

                                return (
                                    <button
                                        key={index}
                                        onClick={() => handleSelectSuggestion(item)}
                                        className='w-full flex items-center gap-3 rounded-xl px-3 py-2 text-left hover:bg-slate-100 dark:hover:bg-white/10 transition-colors'
                                    >
                                        <div className={cn(
                                            'p-2 rounded-lg',
                                            item.type === 'user' && 'bg-emerald-100 text-emerald-600 dark:bg-emerald-500/20 dark:text-emerald-400',
                                            item.type === 'odp' && 'bg-blue-100 text-blue-600 dark:bg-blue-500/20 dark:text-blue-400',
                                            item.type === 'odc' && 'bg-amber-100 text-amber-600 dark:bg-amber-500/20 dark:text-amber-400'
                                        )}>
                                            <IconComp className='h-4 w-4' />
                                        </div>
                                        <div className='min-w-0 flex-1'>
                                            <p className='truncate text-xs font-black text-slate-800 dark:text-white'>
                                                {item.type === 'user' ? maskText(item.name) : item.name}
                                            </p>
                                            <p className='truncate text-[9px] text-slate-400 dark:text-slate-500 mt-0.5'>{item.sub}</p>
                                        </div>
                                    </button>
                                )
                            })}
                        </div>
                    )}
                </div>
                <button onClick={handleSearch} className='h-12 px-6 bg-primary text-primary-foreground rounded-2xl shadow-2xl font-black text-xs uppercase tracking-widest hover:scale-105 active:scale-95 transition-all'>
                    Cari
                </button>
              </div>

              <div className='flex flex-wrap items-center gap-2 xl:justify-end'>
                {[
                  { id: 'all', label: 'Semua', value: totalUsers },
                  { id: 'online', label: 'Online', value: onlineUsers },
                  { id: 'offline', label: 'Offline', value: offlineUsers },
                ].map((f) => (
                  <button
                    key={f.id}
                    onClick={() => setStatusFilter(f.id as any)}
                    className={cn(
                      'rounded-2xl border px-4 py-2.5 text-[10px] font-black uppercase tracking-widest shadow-xl backdrop-blur-xl transition-all',
                      statusFilter === f.id
                        ? 'border-primary bg-primary text-primary-foreground'
                        : 'border-white/30 bg-white/90 hover:bg-white dark:border-white/10 dark:bg-slate-900/90 dark:hover:bg-slate-800'
                    )}
                  >
                    {f.label} <span className='ml-1 opacity-70'>({privacyMode ? '•••' : f.value})</span>
                  </button>
                ))}
                <PrivacyToggle className='h-10 rounded-2xl border border-white/30 bg-white/90 shadow-xl backdrop-blur-xl hover:bg-white dark:border-white/10 dark:bg-slate-900/90 dark:hover:bg-slate-800' />
                <button onClick={goToRouter} className='h-10 w-10 rounded-2xl border border-white/30 bg-white/90 shadow-xl backdrop-blur-xl hover:bg-white dark:border-white/10 dark:bg-slate-900/90 dark:hover:bg-slate-800' title='Fokus router'>
                  <LocateFixed className='mx-auto h-4 w-4' />
                </button>
                <button onClick={fitAllPoints} className='h-10 w-10 rounded-2xl border border-white/30 bg-white/90 shadow-xl backdrop-blur-xl hover:bg-white dark:border-white/10 dark:bg-slate-900/90 dark:hover:bg-slate-800' title='Fit semua titik'>
                  <Maximize2 className='mx-auto h-4 w-4' />
                </button>
              </div>
            </div>

            {/* Loading Overlay */}
            {isMapLoading && activeRouter && (
                <div className='absolute inset-0 z-2000 flex flex-col items-center justify-center bg-slate-950/80 backdrop-blur-sm'>
                    <div className='flex flex-col items-center gap-4 rounded-2xl border border-white/10 bg-slate-900/90 px-10 py-8 shadow-2xl'>
                        <div className='relative'>
                            <div className='h-12 w-12 animate-spin rounded-full border-4 border-indigo-500/30 border-t-indigo-500' />
                            <MapIcon className='absolute inset-0 m-auto h-5 w-5 text-indigo-400' />
                        </div>
                        <div className='text-center'>
                            <p className='text-sm font-black uppercase tracking-widest text-white'>Memuat Peta Jaringan</p>
                            <p className='mt-1 text-[10px] text-slate-400'>Mengambil data ODP, ODC &amp; Pelanggan...</p>
                        </div>
                    </div>
                </div>
            )}

            {/* Sidebar Toggle Button (Only when hidden) */}
            {!showStats && (
                <button
                    onClick={() => setShowStats(true)}
                    className='absolute top-24 left-6 z-1001 flex h-11 w-11 items-center justify-center rounded-2xl border border-border/50 bg-white/95 text-foreground shadow-2xl backdrop-blur-xl transition-all hover:scale-110 hover:bg-white dark:border-white/10 dark:bg-slate-900/90 dark:text-white dark:hover:bg-slate-800 active:scale-95'
                    title='Tampilkan Layers'
                >
                    <Layers className='h-5 w-5' />
                </button>
            )}

            <div className={`absolute top-24 left-6 z-1000 w-64 transition-all duration-300 ${showStats ? 'translate-x-0 opacity-100' : '-translate-x-[calc(100%+30px)] opacity-0 pointer-events-none'}`}>
                {/* Layer Panel */}
                <div className='overflow-hidden rounded-2xl border border-border/50 bg-white/95 shadow-2xl backdrop-blur-2xl dark:border-white/10 dark:bg-slate-900/92'>

                    {/* Header */}
                    <div className='flex items-center justify-between border-b border-border/50 px-4 py-3 dark:border-white/8'>
                        <div className='flex items-center gap-2'>
                            <div className='flex h-7 w-7 items-center justify-center rounded-lg bg-indigo-100 dark:bg-indigo-500/20'>
                                <Layers className='h-3.5 w-3.5 text-indigo-600 dark:text-indigo-400' />
                            </div>
                            <span className='text-[11px] font-black uppercase tracking-[0.12em] text-slate-800 dark:text-white'>Layers</span>
                        </div>
                        <button
                            onClick={() => setShowStats(false)}
                            className='flex h-6 w-6 items-center justify-center rounded-lg text-slate-400 transition hover:bg-slate-100 hover:text-slate-700 dark:hover:bg-white/10 dark:hover:text-white'
                        >
                            <XCircle className='h-3.5 w-3.5' />
                        </button>
                    </div>

                    {/* Layer Items */}
                    <div className='p-2 space-y-0.5'>
                        {[
                            { id: 'odcs',           label: 'ODC',            desc: privacyMode ? '••• titik' : `${totalOdc} titik`,        dot: 'bg-amber-400',   glow: 'shadow-amber-500/40'  },
                            { id: 'odps',           label: 'ODP',            desc: privacyMode ? '••• titik' : `${totalOdp} titik`,        dot: 'bg-blue-400',    glow: 'shadow-blue-500/40'   },
                            { id: 'users',          label: 'Pelanggan',      desc: privacyMode ? '••• user' : `${totalUsers} user`,       dot: 'bg-emerald-400', glow: 'shadow-emerald-500/40'},
                            { id: 'cablesBackbone', label: 'Kabel ODC/ODP',  desc: 'Router → ODP',             dot: 'bg-violet-400',  glow: 'shadow-violet-500/40' },
                            { id: 'cablesCustomer', label: 'Kabel Pelanggan',desc: 'ODP → Pelanggan',          dot: 'bg-cyan-400',    glow: 'shadow-cyan-500/40'   },
                        ].map((l) => {
                            const active = layers[l.id as keyof typeof layers]
                            return (
                                <button
                                    key={l.id}
                                    onClick={() => toggleLayer(l.id as any)}
                                    className={cn(
                                        'flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-all duration-150',
                                        active
                                            ? 'bg-slate-100/80 hover:bg-slate-100 dark:bg-white/8 dark:hover:bg-white/12'
                                             : 'opacity-40 hover:bg-slate-50 hover:opacity-60 dark:hover:bg-white/5'
                                    )}
                                >
                                    {/* Dot indicator */}
                                    <span className={cn(
                                        'h-2 w-2 shrink-0 rounded-full transition-all',
                                        active ? `${l.dot} shadow-sm ${l.glow}` : 'bg-slate-300 dark:bg-slate-600'
                                    )} />

                                    {/* Label */}
                                    <div className='min-w-0 flex-1'>
                                        <p className={cn('truncate text-[11px] font-bold leading-none', active ? 'text-slate-800 dark:text-white' : 'text-slate-400 dark:text-slate-500')}>
                                            {l.label}
                                        </p>
                                        <p className='mt-0.5 truncate text-[9px] text-slate-400 dark:text-slate-600'>{l.desc}</p>
                                    </div>

                                    {/* Toggle pill */}
                                    <div className={cn('relative h-4 w-7 shrink-0 rounded-full transition-colors duration-200', active ? 'bg-indigo-500' : 'bg-slate-200 dark:bg-slate-700')}>
                                        <span className={cn('absolute top-0.5 h-3 w-3 rounded-full bg-white shadow-sm transition-all duration-200', active ? 'left-3.5' : 'left-0.5')} />
                                    </div>
                                </button>
                            )
                        })}
                    </div>
                </div>
            </div>

            {/* Footer Info Bar */}
            <div className='absolute bottom-6 left-1/2 z-1000 -translate-x-1/2'>

                {/* Info Popover Cards */}
                {activeFooterInfo === 'online' && (
                    <div className='mb-2 animate-in fade-in slide-in-from-bottom-2 rounded-2xl border border-emerald-200/60 bg-white/98 px-5 py-3.5 shadow-2xl backdrop-blur-xl dark:border-emerald-800/40 dark:bg-slate-900/98'>
                        <p className='mb-2 text-[9px] font-black uppercase tracking-widest text-emerald-600'>Status Online</p>
                        <div className='flex items-end gap-4'>
                            <div className='text-center'><p className='text-2xl font-black text-emerald-600'>{privacyMode ? '•••' : onlineUsers}</p><p className='text-[9px] text-slate-500'>Pelanggan</p></div>
                            <div className='text-center'><p className='text-2xl font-black text-slate-700 dark:text-slate-200'>{privacyMode ? '•••' : (totalUsers > 0 ? Math.round((onlineUsers / totalUsers) * 100) : 0)}%</p><p className='text-[9px] text-slate-500'>Dari Total</p></div>
                        </div>
                    </div>
                )}
                {activeFooterInfo === 'offline' && (
                    <div className='mb-2 animate-in fade-in slide-in-from-bottom-2 rounded-2xl border border-red-200/60 bg-white/98 px-5 py-3.5 shadow-2xl backdrop-blur-xl dark:border-red-800/40 dark:bg-slate-900/98'>
                        <p className='mb-2 text-[9px] font-black uppercase tracking-widest text-red-600'>Status Offline</p>
                        <div className='flex items-end gap-4'>
                            <div className='text-center'><p className='text-2xl font-black text-red-600'>{privacyMode ? '•••' : offlineUsers}</p><p className='text-[9px] text-slate-500'>Pelanggan</p></div>
                            <div className='text-center'><p className='text-2xl font-black text-slate-700 dark:text-slate-200'>{privacyMode ? '•••' : (totalUsers > 0 ? Math.round((offlineUsers / totalUsers) * 100) : 0)}%</p><p className='text-[9px] text-slate-500'>Dari Total</p></div>
                        </div>
                        <p className='mt-2 text-[9px] text-slate-400'>Klik tombol filter &quot;Offline&quot; di atas untuk menyorot</p>
                    </div>
                )}
                {activeFooterInfo === 'odp' && (
                    <div className='mb-2 animate-in fade-in slide-in-from-bottom-2 rounded-2xl border border-blue-200/60 bg-white/98 px-5 py-3.5 shadow-2xl backdrop-blur-xl dark:border-blue-800/40 dark:bg-slate-900/98'>
                        <p className='mb-2 text-[9px] font-black uppercase tracking-widest text-blue-600'>Keterangan Warna ODP</p>
                        <div className='space-y-1.5'>
                            <div className='flex items-center gap-2.5'><span className='inline-block h-3.5 w-3.5 shrink-0 rounded-full bg-emerald-500 shadow' /><div><p className='text-[11px] font-black text-emerald-700 dark:text-emerald-400'>Hijau — Lega</p><p className='text-[9px] text-slate-500'>Penggunaan port &lt; 70%</p></div></div>
                            <div className='flex items-center gap-2.5'><span className='inline-block h-3.5 w-3.5 shrink-0 rounded-full bg-amber-500 shadow' /><div><p className='text-[11px] font-black text-amber-700 dark:text-amber-400'>Kuning — Hampir Penuh</p><p className='text-[9px] text-slate-500'>Penggunaan port 70–89%</p></div></div>
                            <div className='flex items-center gap-2.5'><span className='inline-block h-3.5 w-3.5 shrink-0 rounded-full bg-red-500 shadow' /><div><p className='text-[11px] font-black text-red-700 dark:text-red-400'>Merah — Penuh</p><p className='text-[9px] text-slate-500'>Penggunaan port ≥ 90%</p></div></div>
                            <div className='flex items-center gap-2.5'><span className='inline-block h-3.5 w-3.5 shrink-0 rounded-full bg-blue-500 shadow' /><div><p className='text-[11px] font-black text-blue-700 dark:text-blue-400'>Biru — Tidak Ada Data</p><p className='text-[9px] text-slate-500'>Kapasitas belum diisi</p></div></div>
                        </div>
                        <p className='mt-2.5 border-t pt-2 text-[9px] text-slate-400'>Total: <span className='font-black text-slate-600 dark:text-slate-300'>{privacyMode ? '•••' : totalOdp} ODP</span> terdaftar</p>
                    </div>
                )}
                {activeFooterInfo === 'odc' && (
                    <div className='mb-2 animate-in fade-in slide-in-from-bottom-2 rounded-2xl border border-amber-200/60 bg-white/98 px-5 py-3.5 shadow-2xl backdrop-blur-xl dark:border-amber-800/40 dark:bg-slate-900/98'>
                        <p className='mb-2 text-[9px] font-black uppercase tracking-widest text-amber-600'>ODC (Optical Distribution Cabinet)</p>
                        <div className='flex items-end gap-4'>
                            <div className='text-center'><p className='text-2xl font-black text-amber-600'>{privacyMode ? '•••' : totalOdc}</p><p className='text-[9px] text-slate-500'>Total ODC</p></div>
                            <div className='text-center'><p className='text-2xl font-black text-slate-700 dark:text-slate-200'>{privacyMode ? '•••' : totalOdp}</p><p className='text-[9px] text-slate-500'>ODP terhubung</p></div>
                        </div>
                        <p className='mt-2 text-[9px] text-slate-400'>ODC adalah titik distribusi utama di jaringan fiber</p>
                    </div>
                )}
                {activeFooterInfo === 'ports' && (
                    <div className='mb-2 animate-in fade-in slide-in-from-bottom-2 rounded-2xl border border-slate-200/60 bg-white/98 px-5 py-3.5 shadow-2xl backdrop-blur-xl dark:border-slate-700/40 dark:bg-slate-900/98'>
                        <p className='mb-2 text-[9px] font-black uppercase tracking-widest text-slate-600 dark:text-slate-400'>Kapasitas Port ODP</p>
                        <div className='flex items-end gap-4'>
                            <div className='text-center'><p className={cn('text-2xl font-black', capacityPercent >= 90 ? 'text-red-600' : capacityPercent >= 70 ? 'text-orange-600' : 'text-emerald-600')}>{privacyMode ? '•••' : `${capacityPercent}%`}</p><p className='text-[9px] text-slate-500'>Terpakai</p></div>
                            <div className='text-center'><p className='text-2xl font-black text-slate-700 dark:text-slate-200'>{privacyMode ? '•••' : usedPorts}</p><p className='text-[9px] text-slate-500'>Port dipakai</p></div>
                            <div className='text-center'><p className='text-2xl font-black text-slate-400'>{privacyMode ? '•••' : totalPorts}</p><p className='text-[9px] text-slate-500'>Total port</p></div>
                        </div>
                        {/* Mini progress bar */}
                        <div className='mt-2.5 h-2 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800'>
                            <div
                                className={cn('h-full rounded-full transition-all', capacityPercent >= 90 ? 'bg-red-500' : capacityPercent >= 70 ? 'bg-orange-400' : 'bg-emerald-500')}
                                style={{ width: `${Math.min(capacityPercent, 100)}%` }}
                            />
                        </div>
                        <p className='mt-1 text-[9px] text-slate-400'>Sisa: <span className='font-black'>{privacyMode ? '•••' : `${Math.max(totalPorts - usedPorts, 0)} port`}</span> kosong</p>
                    </div>
                )}

                {/* Footer Bar — satu baris, tidak wrap */}
                <div
                    className='flex items-center rounded-2xl border border-white/40 bg-white/95 px-1.5 py-1.5 shadow-xl backdrop-blur-xl dark:border-white/10 dark:bg-slate-950/90'
                    onClick={() => setActiveFooterInfo(null)}
                >
                    {([
                        { key: 'online',  icon: <Wifi   className='h-3.5 w-3.5 text-emerald-500' />, value: onlineUsers,  label: 'Online',  vc: 'text-emerald-700 dark:text-emerald-400', hov: 'hover:bg-emerald-50 dark:hover:bg-emerald-950/30', act: 'bg-emerald-50 ring-1 ring-emerald-200 dark:bg-emerald-950/30' },
                        { key: 'offline', icon: <WifiOff className='h-3.5 w-3.5 text-red-500'     />, value: offlineUsers, label: 'Offline', vc: 'text-red-700 dark:text-red-400',         hov: 'hover:bg-red-50 dark:hover:bg-red-950/30',         act: 'bg-red-50 ring-1 ring-red-200 dark:bg-red-950/30'         },
                        { key: 'odp',     icon: <Box    className='h-3.5 w-3.5 text-blue-500'     />, value: totalOdp,     label: 'ODP',     vc: 'text-blue-700 dark:text-blue-400',       hov: 'hover:bg-blue-50 dark:hover:bg-blue-950/30',       act: 'bg-blue-50 ring-1 ring-blue-200 dark:bg-blue-950/30'       },
                        { key: 'odc',     icon: <Server className='h-3.5 w-3.5 text-amber-500'    />, value: totalOdc,     label: 'ODC',     vc: 'text-amber-700 dark:text-amber-400',     hov: 'hover:bg-amber-50 dark:hover:bg-amber-950/30',     act: 'bg-amber-50 ring-1 ring-amber-200 dark:bg-amber-950/30'     },
                    ] as const).map((item, i, arr) => (
                        <div key={item.key} className='flex items-center'>
                            <button
                                onClick={e => { e.stopPropagation(); toggleFooterInfo(item.key) }}
                                className={cn('flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-bold transition-all', item.hov, activeFooterInfo === item.key ? item.act : '')}
                            >
                                {item.icon}
                                <span className={item.vc}>{privacyMode ? '•••' : item.value}</span>
                                <span className='text-slate-500'>{item.label}</span>
                            </button>
                            {i < arr.length - 1 && <div className='mx-0.5 h-4 w-px bg-border' />}
                        </div>
                    ))}

                    <div className='mx-0.5 h-4 w-px bg-border' />

                    <button
                        onClick={e => { e.stopPropagation(); toggleFooterInfo('ports') }}
                        className={cn(
                            'rounded-xl px-3 py-1.5 text-xs font-black transition-all',
                            capacityPercent >= 90 ? 'text-red-600' : capacityPercent >= 70 ? 'text-orange-600' : 'text-emerald-600',
                            activeFooterInfo === 'ports' ? 'bg-slate-50 ring-1 ring-slate-200 dark:bg-slate-800' : 'hover:bg-slate-50 dark:hover:bg-slate-800'
                        )}
                    >
                        Port {privacyMode ? '•••' : `${capacityPercent}%`}
                    </button>
                </div>
            </div>

            {/* Floating Editor Panel for Cable Editing */}
            {editingCable && (() => {
                const currentLen = calculateLineDistance(editingCable.path)
                const originalLen = calculateLineDistance(editingCable.originalPath)
                const diffLen = currentLen - originalLen
                const diffText = diffLen > 0.5 
                    ? `(+${Math.round(diffLen)} m)` 
                    : diffLen < -0.5 
                        ? `(${Math.round(diffLen)} m)` 
                        : `(0 m)`

                return (
                    <div className='absolute top-4 left-1/2 z-1600 -translate-x-1/2 w-[340px] rounded-2xl border border-yellow-300 bg-white/95 p-3.5 shadow-2xl backdrop-blur-md dark:border-yellow-800/40 dark:bg-slate-900/95 animate-in fade-in slide-in-from-top-4 duration-300'>
                        <div className='mb-2.5 flex items-center justify-between'>
                            <div className='flex items-center gap-2'>
                                <span className='h-2 w-2 animate-ping rounded-full bg-yellow-500' />
                                <p className='text-[10px] font-black uppercase tracking-wider text-yellow-600 dark:text-yellow-400'>Mode Edit Kabel</p>
                            </div>
                            <span className='rounded bg-yellow-100 dark:bg-yellow-950 px-1.5 py-0.5 text-[8px] font-black uppercase text-yellow-700 dark:text-yellow-400'>{editingCable.type === 'backbone' ? 'backbone' : 'klien'}</span>
                        </div>
                        
                        <h4 className='text-xs font-black text-slate-800 dark:text-white truncate mb-1'>{editingCable.displayName}</h4>
                        <p className='text-[9px] leading-relaxed text-slate-500 mb-3.5'>
                            Tarik titik biru untuk memindahkan belokan. Tarik titik kuning di tengah garis untuk membuat belokan baru. Klik kanan titik biru untuk menghapus belokan.
                        </p>

                        <div className='mb-3 flex items-center justify-between rounded-xl bg-slate-50 px-3 py-2 text-[10px] dark:bg-slate-800/70'>
                            <span className='font-bold text-slate-500'>Panjang Kabel:</span>
                            <span className='font-black text-slate-800 dark:text-white'>
                                {formatDistance(currentLen)}{' '}
                                <span className={diffLen > 0.5 ? 'text-rose-500 dark:text-rose-400' : diffLen < -0.5 ? 'text-emerald-500 dark:text-emerald-400' : 'text-slate-400'}>
                                    {diffText}
                                </span>
                            </span>
                        </div>

                        <div className='flex items-center justify-between gap-2 border-t border-slate-100 dark:border-slate-800 pt-3'>
                            <button
                                onClick={cancelEditCable}
                                className='rounded-xl border border-slate-200 dark:border-slate-700 px-3 py-2 text-[9px] font-black uppercase text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors'
                            >
                                Batal
                            </button>
                            <div className='flex gap-1.5'>
                                <button
                                    onClick={resetToStraight}
                                    className='rounded-xl border border-red-200 bg-red-50 dark:bg-red-950/20 dark:border-red-900/40 px-3 py-2 text-[9px] font-black uppercase text-red-600 dark:text-red-400 hover:bg-red-100 dark:hover:bg-red-950/30 transition-colors'
                                >
                                    Reset Lurus
                                </button>
                                <button
                                    onClick={saveCablePath}
                                    className='rounded-xl bg-yellow-500 hover:bg-yellow-600 text-slate-900 px-4.5 py-2 text-[9px] font-black uppercase shadow-xs transition-colors'
                                >
                                    Simpan Jalur
                                </button>
                            </div>
                        </div>
                    </div>
                )
            })()}
        </div>
      </Main>
    </>
  )
}
