import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import {
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend
} from 'recharts'
import { Users, Router, ShieldCheck, Activity } from 'lucide-react'

interface AnalyticsProps {
  stats?: any
}

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#14b8a6', '#f97316']

export function Analytics({ stats }: AnalyticsProps) {
  // Parse profile distribution
  const profileData = stats?.profile_distribution 
    ? Object.keys(stats.profile_distribution).map((key) => ({
        name: key,
        value: stats.profile_distribution[key]
      })).sort((a, b) => b.value - a.value)
    : []

  // Parse revenue history
  const revenueData = stats?.revenue_history || []

  const formatIDR = (value: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      maximumFractionDigits: 0,
      minimumFractionDigits: 0,
    }).format(value)
  }

  const formatIDRCompact = (value: number) => {
     if (value >= 1000000) {
        return `Rp ${(value / 1000000).toFixed(1)}Jt`
     }
     if (value >= 1000) {
        return `Rp ${(value / 1000).toFixed(0)}Rb`
     }
     return `Rp ${value}`
  }

  return (
    <div className='space-y-4 mt-4'>

      <div className='grid grid-cols-1 gap-4 lg:grid-cols-7'>
        <Card className='col-span-1 lg:col-span-4 bg-card/50 backdrop-blur-sm shadow-xl border-none'>
          <CardHeader>
            <CardTitle className="text-lg font-black uppercase tracking-tight">Tren Arus Kas Bulanan</CardTitle>
            <CardDescription className="text-[10px] font-bold uppercase tracking-widest opacity-60">Riwayat Pendapatan & Pengeluaran 6 Bulan Terakhir</CardDescription>
          </CardHeader>
          <CardContent className='px-6'>
            {revenueData.length > 0 ? (
              <div className="h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={revenueData} margin={{ top: 20, right: 0, left: 0, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#888888" opacity={0.1} />
                    <XAxis 
                       dataKey="month" 
                       stroke="#888888" 
                       fontSize={10} 
                       tickLine={false} 
                       axisLine={false}
                    />
                    <YAxis 
                       stroke="#888888" 
                       fontSize={10} 
                       tickLine={false} 
                       axisLine={false}
                       tickFormatter={(value) => formatIDRCompact(value)}
                    />
                    <Tooltip 
                       contentStyle={{ 
                         borderRadius: '12px', 
                         border: 'none', 
                         boxShadow: '0 10px 25px rgba(0,0,0,0.2)',
                         fontSize: '11px',
                         fontWeight: 'bold',
                         backgroundColor: 'rgba(15, 23, 42, 0.9)',
                         color: '#fff'
                       }}
                       cursor={{ fill: 'rgba(15, 23, 42, 0.1)' }}
                       formatter={(value: any, name: any) => [formatIDR(Number(value)), name === 'revenue' ? "Pendapatan" : "Pengeluaran"]}
                    />
                    <Legend wrapperStyle={{ fontSize: '10px', fontWeight: 'bold' }} />
                    <Bar 
                       dataKey="revenue" 
                       name="Pendapatan"
                       fill="#10b981" 
                       radius={[4, 4, 0, 0]}
                       maxBarSize={50}
                    />
                    <Bar 
                       dataKey="expense" 
                       name="Pengeluaran"
                       fill="#f43f5e" 
                       radius={[4, 4, 0, 0]}
                       maxBarSize={50}
                    />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <div className="h-[300px] flex items-center justify-center text-[10px] font-bold uppercase text-muted-foreground">
                 Belum ada data pendapatan
              </div>
            )}
          </CardContent>
        </Card>
        
        <Card className='col-span-1 lg:col-span-3 bg-card/50 backdrop-blur-sm shadow-xl border-none flex flex-col'>
          <CardHeader>
            <CardTitle className="text-lg font-black uppercase tracking-tight">Distribusi Paket</CardTitle>
            <CardDescription className="text-[10px] font-bold uppercase tracking-widest opacity-60">Persentase Penggunaan Profil PPPoE</CardDescription>
          </CardHeader>
          <CardContent className="flex-1 flex flex-col justify-center pb-6">
             {profileData.length > 0 ? (
                <div className="h-[250px]">
                   <ResponsiveContainer width="100%" height="100%">
                     <PieChart>
                       <Pie
                         data={profileData}
                         cx="50%"
                         cy="50%"
                         innerRadius={60}
                         outerRadius={90}
                         paddingAngle={2}
                         dataKey="value"
                         stroke="none"
                       >
                         {profileData.map((entry: any, index: number) => (
                           <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                         ))}
                       </Pie>
                       <Tooltip 
                          contentStyle={{ 
                            borderRadius: '12px', 
                            border: 'none', 
                            boxShadow: '0 10px 25px rgba(0,0,0,0.2)',
                            fontSize: '11px',
                            fontWeight: 'bold',
                            backgroundColor: 'rgba(15, 23, 42, 0.9)',
                            color: '#fff'
                          }}
                          itemStyle={{ padding: '2px 0' }}
                          formatter={(value: any) => [`${value} Pelanggan`]}
                       />
                       <Legend 
                          layout="horizontal" 
                          verticalAlign="bottom" 
                          align="center"
                          wrapperStyle={{ fontSize: '10px', fontWeight: 'bold', paddingTop: '20px' }}
                          formatter={(value) => <span className="uppercase tracking-wider ml-1">{value}</span>}
                       />
                     </PieChart>
                   </ResponsiveContainer>
                </div>
             ) : (
                <div className="h-[250px] flex items-center justify-center text-[10px] font-bold uppercase text-muted-foreground">
                   Belum ada data profil
                </div>
             )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
