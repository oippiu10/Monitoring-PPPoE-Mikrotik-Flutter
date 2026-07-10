import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  Activity,
  RefreshCw,
  Search,
  User,
  Clock,
  Filter,
} from 'lucide-react'
import { api } from '@/lib/api'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { ThemeSwitch } from '@/components/theme-switch'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

interface ActivityLog {
  id: number
  user_id: number | null
  action: string
  description: string | null
  ip_address: string | null
  created_at: string
  username?: string
}

export function ActivityLogs() {
  const [search, setSearch] = useState('')
  const [actionFilter, setActionFilter] = useState('all')
  const [page, setPage] = useState(1)
  const limit = 50

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ['activity-logs', page, actionFilter],
    queryFn: async () => {
      const res = await api.get('/get_activity_logs.php', {
        params: { page, limit, action: actionFilter !== 'all' ? actionFilter : undefined },
      })
      return res.data
    },
    staleTime: 30000,
  })

  const logs: ActivityLog[] = data?.data || []

  const filtered = search
    ? logs.filter(
        (l) =>
          l.action?.toLowerCase().includes(search.toLowerCase()) ||
          l.description?.toLowerCase().includes(search.toLowerCase()) ||
          l.username?.toLowerCase().includes(search.toLowerCase())
      )
    : logs

  const getActionBadge = (action: string) => {
    const map: Record<string, string> = {
      login: 'bg-green-500/10 text-green-600 dark:text-green-400 ring-1 ring-green-500/20 border-transparent',
      logout: 'bg-slate-500/10 text-slate-600 dark:text-slate-400 ring-1 ring-slate-500/20 border-transparent',
      delete: 'bg-red-500/10 text-red-600 dark:text-red-400 ring-1 ring-red-500/20 border-transparent',
      create: 'bg-blue-500/10 text-blue-600 dark:text-blue-400 ring-1 ring-blue-500/20 border-transparent',
      update: 'bg-yellow-500/10 text-yellow-600 dark:text-yellow-400 ring-1 ring-yellow-500/20 border-transparent',
      isolir: 'bg-orange-500/10 text-orange-600 dark:text-orange-400 ring-1 ring-orange-500/20 border-transparent',
      payment: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 ring-1 ring-emerald-500/20 border-transparent',
    }
    const key = Object.keys(map).find((k) => action?.toLowerCase().includes(k))
    return key ? map[key] : 'bg-primary/10 text-primary ring-1 ring-primary/20 border-transparent'
  }

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  return (
    <>
      <Header>
        <div className='flex items-center gap-2 me-auto'>
          <Activity className='h-5 w-5 text-primary' />
          <span className='font-bold text-sm uppercase tracking-wider'>Log Aktivitas</span>
        </div>
        <ThemeSwitch />
        <ProfileDropdown />
      </Header>

      <Main>
        <div className='mb-6'>
          <div className='flex items-center gap-2 mb-1'>
            <div className='p-1.5 bg-primary/10 rounded-md'>
              <Activity className='w-4 h-4 text-primary' />
            </div>
            <span className='text-[10px] font-bold uppercase tracking-[0.2em] text-muted-foreground'>
              Sistem
            </span>
          </div>
          <h1 className='text-3xl font-black tracking-tight bg-linear-to-br from-foreground to-foreground/70 bg-clip-text text-transparent'>Log Aktivitas</h1>
          <p className='text-muted-foreground text-sm font-medium mt-1'>
            Rekam jejak semua aktivitas administrator dalam sistem.
          </p>
        </div>

        {/* Stats Cards */}
        <div className='grid gap-3 sm:grid-cols-3 mb-6'>
          <Card className='border border-primary/15 shadow-md shadow-primary/5 bg-linear-to-br from-primary/5 via-transparent to-transparent backdrop-blur-xs rounded-xl'>
            <CardContent className='flex items-center gap-3 p-4'>
              <div className='p-2 bg-primary/10 rounded-lg text-primary ring-1 ring-primary/20 shadow-inner'>
                <Activity className='h-5 w-5' />
              </div>
              <div>
                <p className='text-[10px] font-bold uppercase tracking-widest text-muted-foreground/80'>Total Log</p>
                <p className='text-xl font-black tracking-tight'>
                  {data?.total || logs.length}
                </p>
              </div>
            </CardContent>
          </Card>
          
          <Card className='border border-blue-500/15 shadow-md shadow-blue-500/5 bg-linear-to-br from-blue-500/5 via-transparent to-transparent backdrop-blur-xs rounded-xl'>
            <CardContent className='flex items-center gap-3 p-4'>
              <div className='p-2 bg-blue-500/10 rounded-lg text-blue-600 dark:text-blue-400 ring-1 ring-blue-500/20 shadow-inner'>
                <Clock className='h-5 w-5' />
              </div>
              <div>
                <p className='text-[10px] font-bold uppercase tracking-widest text-muted-foreground/80'>Aktivitas Hari Ini</p>
                <p className='text-xl font-black tracking-tight'>
                  {
                    logs.filter((l) => {
                      const today = new Date().toDateString()
                      return new Date(l.created_at).toDateString() === today
                    }).length
                  }
                </p>
              </div>
            </CardContent>
          </Card>

          <Card className='border border-purple-500/15 shadow-md shadow-purple-500/5 bg-linear-to-br from-purple-500/5 via-transparent to-transparent backdrop-blur-xs rounded-xl'>
            <CardContent className='flex items-center gap-3 p-4'>
              <div className='p-2 bg-purple-500/10 rounded-lg text-purple-600 dark:text-purple-400 ring-1 ring-purple-500/20 shadow-inner'>
                <User className='h-5 w-5' />
              </div>
              <div>
                <p className='text-[10px] font-bold uppercase tracking-widest text-muted-foreground/80'>Unik Admin</p>
                <p className='text-xl font-black tracking-tight'>
                  {new Set(logs.map((l) => l.user_id).filter(Boolean)).size}
                </p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Table */}
        <Card className='overflow-hidden border border-border/40 shadow-xl rounded-2xl bg-card/50 backdrop-blur-sm'>
          <CardHeader className='flex flex-col sm:flex-row sm:items-center justify-between gap-4 px-5 py-4 bg-card/80 border-b border-border/40'>
            <div>
              <CardTitle className='text-lg font-black uppercase tracking-tight'>
                Riwayat Aktivitas
              </CardTitle>
              <CardDescription className='text-[10px] font-bold uppercase tracking-widest opacity-60'>
                {filtered.length} catatan ditemukan
              </CardDescription>
            </div>
            <div className='flex items-center gap-2'>
              <div className='relative'>
                <Search className='absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground/60' />
                <Input
                  placeholder='Cari aktivitas...'
                  className='pl-9 h-9 w-48 text-sm rounded-lg bg-muted/40 border-transparent shadow-none focus-visible:ring-primary/20 focus-visible:bg-background transition-all'
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
              </div>
              <Select value={actionFilter} onValueChange={setActionFilter}>
                <SelectTrigger className='h-9 w-36 text-xs font-bold rounded-lg bg-muted/40 border-transparent shadow-none hover:bg-muted/60 transition-all'>
                  <Filter className='h-3.5 w-3.5 mr-1' />
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className="rounded-xl">
                  <SelectItem value='all'>Semua Aksi</SelectItem>
                  <SelectItem value='login'>Login</SelectItem>
                  <SelectItem value='logout'>Logout</SelectItem>
                  <SelectItem value='create'>Buat</SelectItem>
                  <SelectItem value='update'>Update</SelectItem>
                  <SelectItem value='delete'>Hapus</SelectItem>
                  <SelectItem value='payment'>Pembayaran</SelectItem>
                  <SelectItem value='isolir'>Isolir</SelectItem>
                </SelectContent>
              </Select>
              <Button
                variant='outline'
                size='icon'
                className='h-9 w-9 rounded-lg border-transparent bg-muted/40 hover:bg-muted/60 transition-all'
                onClick={() => refetch()}
                title="Refresh Data"
                disabled={isFetching}
              >
                <RefreshCw className={`h-4 w-4 ${isFetching ? 'animate-spin' : ''}`} />
              </Button>
            </div>
          </CardHeader>
          <CardContent className='p-0'>
            {isLoading ? (
              <div className='flex items-center justify-center h-48 text-muted-foreground text-sm'>
                <RefreshCw className='h-4 w-4 animate-spin mr-2' />
                Memuat log aktivitas...
              </div>
            ) : filtered.length === 0 ? (
              <div className='flex flex-col items-center justify-center h-48 text-muted-foreground'>
                <Activity className='h-8 w-8 mb-2 opacity-30' />
                <p className='text-sm font-medium'>Belum ada log aktivitas</p>
              </div>
            ) : (
              <div className='overflow-x-auto'>
                <Table>
                  <TableHeader className='bg-transparent border-b border-border/40'>
                    <TableRow className='hover:bg-transparent'>
                      <TableHead className='text-[10px] font-bold uppercase tracking-widest text-muted-foreground w-10 pl-5 h-10'>
                        #
                      </TableHead>
                      <TableHead className='text-[10px] font-bold uppercase tracking-widest text-muted-foreground h-10'>
                        Waktu
                      </TableHead>
                      <TableHead className='text-[10px] font-bold uppercase tracking-widest text-muted-foreground h-10'>
                        Admin
                      </TableHead>
                      <TableHead className='text-[10px] font-bold uppercase tracking-widest text-muted-foreground h-10'>
                        Aksi
                      </TableHead>
                      <TableHead className='text-[10px] font-bold uppercase tracking-widest text-muted-foreground h-10'>
                        Deskripsi
                      </TableHead>
                      <TableHead className='text-[10px] font-bold uppercase tracking-widest text-muted-foreground h-10 pr-5'>
                        IP Address
                      </TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {filtered.map((log, i) => (
                      <TableRow key={log.id} className='border-border/30 hover:bg-muted/40 transition-colors'>
                        <TableCell className='text-muted-foreground text-xs pl-5 font-mono'>
                          {(page - 1) * limit + i + 1}
                        </TableCell>
                        <TableCell className='text-xs text-muted-foreground whitespace-nowrap'>
                          {formatDate(log.created_at)}
                        </TableCell>
                        <TableCell>
                          <div className='flex items-center gap-1.5'>
                            <div className='w-5 h-5 rounded-full bg-primary/10 flex items-center justify-center'>
                              <User className='w-2.5 h-2.5 text-primary' />
                            </div>
                            <span className='text-xs font-medium'>
                              {log.username || `User #${log.user_id || 'System'}`}
                            </span>
                          </div>
                        </TableCell>
                        <TableCell>
                          <Badge
                            variant='outline'
                            className={`text-[9px] font-bold uppercase tracking-wider ${getActionBadge(log.action)}`}
                          >
                            {log.action}
                          </Badge>
                        </TableCell>
                        <TableCell className='text-xs text-muted-foreground max-w-sm truncate'>
                          {log.description || '-'}
                        </TableCell>
                        <TableCell className='text-[11px] font-mono font-medium text-muted-foreground/80 pr-5'>
                          {log.ip_address || '-'}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Pagination */}
        {data?.total > limit && (
          <div className='flex items-center justify-between mt-4 text-xs text-muted-foreground'>
            <span>
              Menampilkan {(page - 1) * limit + 1} - {Math.min(page * limit, data.total)} dari{' '}
              {data.total} log
            </span>
            <div className='flex gap-2'>
              <Button
                variant='outline'
                size='sm'
                disabled={page === 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                className='h-8 text-xs'
              >
                Sebelumnya
              </Button>
              <Button
                variant='outline'
                size='sm'
                disabled={page * limit >= data.total}
                onClick={() => setPage((p) => p + 1)}
                className='h-8 text-xs'
              >
                Berikutnya
              </Button>
            </div>
          </div>
        )}
      </Main>
    </>
  )
}
