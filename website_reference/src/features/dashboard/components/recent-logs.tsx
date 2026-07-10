import { useState } from 'react'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Search, FilterX, Terminal, History, Info, AlertTriangle, XCircle, ChevronRight, ActivitySquare } from 'lucide-react'
import { cn } from '@/lib/utils'

interface MikrotikLog {
  '.id'?: string | null
  time?: string | null
  topics?: string | null
  message?: string | null
}

interface SystemLog {
  action: string
  time: string
}

interface RecentLogsProps {
  mikrotikLogs?: MikrotikLog[]
  systemLogs?: SystemLog[]
}

export function RecentLogs({ mikrotikLogs = [], systemLogs = [] }: RecentLogsProps) {
  const [search, setSearch] = useState('')
  const [hidePPPoE, setHidePPPoE] = useState(false)

  const filteredLogs = mikrotikLogs.filter(log => {
    const message = String(log.message || '')
    const topics = String(log.topics || '')
    const q = search.trim().toLowerCase()
    const msgMatch = message.toLowerCase().includes(q)
    const topicMatch = topics.toLowerCase().includes(q)
    const isPPPoE = message.toLowerCase().includes('pppoe connection established') || topics.toLowerCase().includes('pppoe')
    
    // Jika filter aktif, sembunyikan log PPPoE kecuali sedang dicari secara spesifik
    if (hidePPPoE && isPPPoE && !q) return false
    return msgMatch || topicMatch
  })

  const getTopicStyle = (topic?: string | null) => {
    const t = String(topic || '').toLowerCase().trim()
    if (t.includes('error') || t.includes('critical') || t.includes('failed')) return { bg: 'bg-red-500/10 text-red-600 dark:text-red-400 border-red-500/20', icon: <XCircle className="w-3 h-3 text-red-500" /> }
    if (t.includes('warning') || t.includes('alert')) return { bg: 'bg-orange-500/10 text-orange-600 dark:text-orange-400 border-orange-500/20', icon: <AlertTriangle className="w-3 h-3 text-orange-500" /> }
    if (t.includes('pppoe') || t.includes('ppp') || t.includes('account')) return { bg: 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-500/20', icon: <Info className="w-3 h-3 text-blue-500" /> }
    if (t.includes('system') || t.includes('info')) return { bg: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20', icon: <Terminal className="w-3 h-3 text-emerald-500" /> }
    if (t.includes('script')) return { bg: 'bg-purple-500/10 text-purple-600 dark:text-purple-400 border-purple-500/20', icon: <Terminal className="w-3 h-3 text-purple-500" /> }
    return { bg: 'bg-primary/5 text-primary/60 border-primary/10', icon: <ChevronRight className="w-3 h-3 text-primary/50" /> }
  }

  const getMessageColor = (topics?: string | null) => {
    const t = String(topics || '').toLowerCase()
    if (t.includes('error') || t.includes('critical') || t.includes('failed')) return 'text-red-600 dark:text-red-400 font-bold'
    if (t.includes('warning') || t.includes('alert')) return 'text-orange-600 dark:text-orange-400 font-bold'
    return 'text-muted-foreground'
  }

  return (
    <div className='grid grid-cols-1 gap-4 lg:grid-cols-3'>
      {/* Kolom 1: Mikrotik Logs */}
      <div className='lg:col-span-2 overflow-hidden rounded-xl border border-muted/50 bg-background shadow-xl flex flex-col'>
        <div className='flex flex-wrap items-center justify-between gap-3 p-3 bg-muted/30 border-b border-muted/30 shrink-0'>
          <div className='flex items-center gap-2'>
            <div className="p-1.5 bg-primary/10 rounded-md">
               <Terminal className='w-4 h-4 text-primary' />
            </div>
            <div>
               <h3 className='text-[11px] font-black uppercase tracking-widest leading-none'>MikroTik Device Logs</h3>
               <p className="text-[9px] font-bold text-muted-foreground uppercase opacity-70 mt-0.5">Real-time System Output</p>
            </div>
          </div>
          <div className='flex items-center gap-2'>
            <div className='relative'>
              <Search className='absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-muted-foreground/60' />
              <Input 
                placeholder='Search logs...' 
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className='h-8 w-[160px] pl-8 text-[11px] font-medium bg-background focus-visible:ring-primary border-muted-foreground/20'
              />
            </div>
            <Button 
              variant={hidePPPoE ? 'default' : 'outline'} 
              size='sm' 
              onClick={() => setHidePPPoE(!hidePPPoE)}
              className='h-8 px-3 text-[10px] gap-1.5 font-bold uppercase transition-colors'
            >
              <FilterX className='w-3.5 h-3.5' />
              {hidePPPoE ? 'PPPoE Hidden' : 'Hide PPPoE'}
            </Button>
          </div>
        </div>
        
        <div className='flex-1 max-h-[600px] overflow-auto bg-background/50 dark:bg-background custom-scrollbar p-2'>
           <div className="flex flex-col gap-1 min-w-[500px]">
             {filteredLogs.length === 0 ? (
                <div className='flex items-center justify-center py-12'>
                  <p className="text-[10px] font-bold text-muted-foreground/50 uppercase tracking-widest border border-dashed border-muted-foreground/20 rounded-lg px-4 py-2">
                     {search || hidePPPoE ? 'No logs match filters' : 'No recent logs found'}
                  </p>
                </div>
             ) : (
                filteredLogs.map((log, i) => {
                   const tStyle = getTopicStyle(log.topics)
                   return (
                      <div key={i} className='group flex items-start gap-3 py-1.5 px-2 hover:bg-muted/50 dark:hover:bg-white/5 rounded-md transition-colors border-b border-muted-foreground/10 last:border-0'>
                         <div className="flex items-center shrink-0 w-[60px] pt-0.5">
                            <span className="text-[10px] font-mono text-muted-foreground/70">{log.time}</span>
                         </div>
                         
                         <div className="flex flex-wrap items-center gap-1.5 shrink-0 w-[160px] pt-0.5">
                            {log.topics?.split(',').map((t, ti) => {
                               const localStyle = getTopicStyle(t)
                               return (
                                  <span key={ti} className={cn('text-[9px] font-bold px-1.5 rounded-sm border whitespace-nowrap py-0.5 flex items-center gap-1', localStyle.bg)}>
                                     {t.trim()}
                                  </span>
                               )
                            })}
                         </div>
                         
                         <div className="flex-1 min-w-0">
                            <span className={cn('text-[11px] font-mono leading-relaxed wrap-break-word block', getMessageColor(log.topics))}>
                               {log.message}
                            </span>
                         </div>
                      </div>
                   )
                })
             )}
           </div>
        </div>
      </div>

      {/* Kolom 2: System Application Logs */}
      <div className='overflow-hidden rounded-xl border border-muted/50 bg-background shadow-xl flex flex-col'>
        <div className='flex items-center gap-3 p-3 bg-muted/30 border-b border-muted/30 shrink-0'>
          <div className="p-1.5 bg-emerald-500/10 rounded-md">
             <ActivitySquare className='w-4 h-4 text-emerald-500' />
          </div>
          <div>
             <h3 className='text-[11px] font-black uppercase tracking-widest leading-none'>App Activity Logs</h3>
             <p className="text-[9px] font-bold text-muted-foreground uppercase opacity-70 mt-0.5">User Action History</p>
          </div>
        </div>
        
        <div className='flex-1 max-h-[600px] overflow-auto p-4 custom-scrollbar'>
           <div className="relative border-l border-muted-foreground/20 ml-3 space-y-6 pb-4">
             {systemLogs.length === 0 ? (
               <div className="ml-4 flex items-center justify-center py-8">
                  <p className="text-[10px] font-bold text-muted-foreground/50 uppercase border border-dashed border-muted-foreground/20 rounded-lg px-4 py-2">
                     No activity found
                  </p>
               </div>
             ) : (
               systemLogs.map((log, i) => (
                 <div key={i} className="relative pl-6">
                    <div className="absolute -left-1.5 top-1 w-3 h-3 rounded-full bg-emerald-500 border-[3px] border-background shadow-sm shadow-emerald-500/50" />
                    <div className="flex flex-col gap-1">
                       <span className="text-[10px] font-mono text-muted-foreground">{log.time}</span>
                       <div className="bg-muted/30 rounded-lg p-2.5 border border-muted-foreground/10 hover:bg-muted/50 transition-colors">
                          <span className="text-[11px] font-bold text-foreground leading-tight">
                             {log.action || 'Sistem melakukan sinkronisasi latar belakang'}
                          </span>
                       </div>
                    </div>
                 </div>
               ))
             )}
           </div>
        </div>
      </div>
    </div>
  )
}
