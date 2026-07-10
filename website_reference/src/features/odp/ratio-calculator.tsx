import { useState, useMemo } from 'react'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { ThemeSwitch } from '@/components/theme-switch'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { ODPSubNav } from './components/odp-sub-nav'
import { Zap, ShieldAlert, CheckCircle2, Info, Check, ChevronsUpDown } from 'lucide-react'
import { cn } from '@/lib/utils'

const LOCAL_SPLITTER_LOSS_MAP: Record<number, number> = {
  2: 3,
  4: 7,
  8: 10,
  16: 14,
  32: 17,
  64: 20,
}

export function ODPRatioCalculator() {
  const [inputPower, setInputPower] = useState<string>('-5.00')
  const [tapPercent, setTapPercent] = useState<number>(10)
  const [localSplitter, setLocalSplitter] = useState<number>(8)
  const [odpConnection, setOdpConnection] = useState<'TAP' | 'THRU'>('TAP')
  const [isRatioPopoverOpen, setIsRatioPopoverOpen] = useState(false)

  const thruPercent = 100 - tapPercent

  const calculations = useMemo(() => {
    const rxIn = parseFloat(inputPower) || 0

    // Formulas matching Excel Sheet3 lookup: -10 * log10(percent / 100) + 0.25
    const tapLoss = parseFloat((-10 * Math.log10(tapPercent / 100) + 0.25).toFixed(2))
    const thruLoss = parseFloat((-10 * Math.log10(thruPercent / 100) + 0.25).toFixed(2))

    const tapOutput = parseFloat((rxIn - tapLoss).toFixed(2))
    const thruOutput = parseFloat((rxIn - thruLoss).toFixed(2))

    // Selected connection to ODP
    const baseOutput = odpConnection === 'TAP' ? tapOutput : thruOutput
    const splitterLoss = LOCAL_SPLITTER_LOSS_MAP[localSplitter] || 10
    const finalOdpOutput = parseFloat((baseOutput - splitterLoss).toFixed(2))

    // Forwarded connection (unused port) to next ODP
    const forwardedOutput = odpConnection === 'TAP' ? thruOutput : tapOutput
    const forwardedPercent = odpConnection === 'TAP' ? thruPercent : tapPercent

    return {
      tapLoss,
      thruLoss,
      tapOutput,
      thruOutput,
      splitterLoss,
      finalOdpOutput,
      baseOutput,
      forwardedOutput,
      forwardedPercent,
    }
  }, [inputPower, tapPercent, localSplitter, odpConnection, thruPercent])

  const isLowSignal = calculations.finalOdpOutput < -25

  return (
    <>
      <Header>
        <div className='flex items-center justify-between w-full'>
          <div className='flex items-center gap-2'>
            <span className='font-bold text-sm text-muted-foreground'>Fiber Mapping</span>
            <span className='text-muted-foreground text-xs'>/</span>
            <span className='font-bold text-sm'>Kalkulator Splitter Rasio</span>
          </div>
          <div className='flex items-center gap-3'>
            <ThemeSwitch />
            <ProfileDropdown />
          </div>
        </div>
      </Header>

      <Main>
        <div className='mb-6 space-y-0.5'>
          <h1 className='text-2xl font-black tracking-tight text-slate-800 dark:text-slate-100'>
            Kalkulator Rasio ODP
          </h1>
          <p className='text-sm text-muted-foreground'>
            Masukkan nilai redaman, pilih rasio, perutean port, dan kapasitas ODP untuk melihat hasil perhitungan daya.
          </p>
        </div>

        <div className='mb-6'>
          <ODPSubNav active='/odp/ratio-calculator' />
        </div>

        <div className='flex flex-col gap-6 max-w-5xl mx-auto'>
          {/* Parameter Inputs Card */}
          <Card className='w-full border-none shadow-xl bg-card border text-card-foreground'>
            <CardHeader className='pb-4 border-b bg-muted/30'>
              <CardTitle className='text-sm font-black text-slate-800 dark:text-slate-200 uppercase tracking-wider flex items-center gap-2'>
                <Zap className='h-4 w-4 text-orange-500' />
                Parameter Perhitungan
              </CardTitle>
              <CardDescription className='text-xs'>
                Konfigurasi rasio & splitter lokal.
              </CardDescription>
            </CardHeader>
            <CardContent className='py-8 px-6 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6'>
              {/* Input Power */}
              <div className='flex flex-col gap-3 min-w-0 w-full'>
                <label className='text-[11px] font-black uppercase text-muted-foreground tracking-wider truncate block h-4'>
                  1. Redaman Masuk (dBm)
                </label>
                <div className='relative w-full h-12'>
                  <Input
                    type='number'
                    step='0.01'
                    value={inputPower}
                    onChange={(e) => setInputPower(e.target.value)}
                    className='w-full font-mono font-black text-xl h-12 pl-4 pr-16 shadow-inner min-w-0 border-slate-200 dark:border-slate-800'
                  />
                  <div className='absolute right-2 top-1/2 -translate-y-1/2 bg-muted px-3 py-1 flex items-center justify-center font-bold text-xs rounded-md border text-muted-foreground h-8'>
                    dBm
                  </div>
                </div>
              </div>

              {/* Ratio Selection */}
              <div className='flex flex-col gap-3 min-w-0 w-full'>
                <label className='text-[11px] font-black uppercase text-muted-foreground tracking-wider truncate block h-4'>
                  2. Rasio Splitter Asymmetric
                </label>
                <Popover open={isRatioPopoverOpen} onOpenChange={setIsRatioPopoverOpen}>
                  <PopoverTrigger asChild>
                    <Button
                      variant="outline"
                      role="combobox"
                      aria-expanded={isRatioPopoverOpen}
                      className="w-full justify-between h-12 text-sm font-black font-mono shadow-sm px-3 border-slate-200 dark:border-slate-800"
                    >
                      Rasio {tapPercent} / {100 - tapPercent}
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-[300px] p-0" align="start">
                    <Command>
                      <CommandInput placeholder="Cari rasio (misal: 10)..." />
                      <CommandList>
                        <CommandEmpty>Rasio tidak ditemukan.</CommandEmpty>
                        <CommandGroup className="max-h-[300px] overflow-auto">
                          {Array.from({ length: 50 }, (_, i) => i + 1).map((val) => (
                            <CommandItem
                              key={val}
                              value={`${val} ${100 - val} rasio ${val}/${100 - val}`}
                              onSelect={(currentValue) => {
                                setTapPercent(parseInt(currentValue.split(' ')[0]))
                                setIsRatioPopoverOpen(false)
                              }}
                              className="font-mono font-bold text-xs"
                            >
                              <Check
                                className={cn(
                                  "mr-2 h-4 w-4",
                                  tapPercent === val ? "opacity-100" : "opacity-0"
                                )}
                              />
                              Rasio {val} / {100 - val}
                            </CommandItem>
                          ))}
                        </CommandGroup>
                      </CommandList>
                    </Command>
                  </PopoverContent>
                </Popover>
              </div>

              {/* Local ODP Connection Routing */}
              <div className='flex flex-col gap-3 min-w-0 w-full'>
                <label className='text-[11px] font-black uppercase text-muted-foreground tracking-wider truncate block h-4'>
                  3. Sinyal Untuk ODP Ini:
                </label>
                <Select
                  value={odpConnection}
                  onValueChange={(val) => setOdpConnection(val as 'TAP' | 'THRU')}
                >
                  <SelectTrigger className='w-full h-12 text-xs font-black shadow-sm truncate border-slate-200 dark:border-slate-800'>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value='TAP' className='text-xs font-bold'>
                      🔴 Pakai yang {tapPercent}%
                    </SelectItem>
                    <SelectItem value='THRU' className='text-xs font-bold'>
                      🟢 Pakai yang {thruPercent}%
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>

              {/* Local Splitter Capacity */}
              <div className='flex flex-col gap-3 min-w-0 w-full'>
                <label className='text-[11px] font-black uppercase text-muted-foreground tracking-wider truncate block h-4'>
                  4. Kapasitas Splitter Lokal
                </label>
                <Select
                  value={localSplitter.toString()}
                  onValueChange={(val) => setLocalSplitter(parseInt(val))}
                >
                  <SelectTrigger className='w-full h-12 text-xs xl:text-sm font-black font-mono shadow-sm truncate border-slate-200 dark:border-slate-800'>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {[2, 4, 8, 16, 32, 64].map((val) => (
                      <SelectItem key={val} value={val.toString()} className='text-xs font-mono font-bold'>
                        1:{val} (-{LOCAL_SPLITTER_LOSS_MAP[val]} dB)
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </CardContent>
          </Card>

          {/* Results Display Visualizer - Tree Layout */}
          <div className='w-full rounded-3xl bg-slate-950 text-slate-50 overflow-hidden shadow-2xl relative border border-slate-800/80 p-8 flex flex-col items-center justify-center py-16'>
            {/* Background Glows */}
            <div className='absolute -top-32 -right-32 w-96 h-96 bg-primary/20 blur-[100px] rounded-full pointer-events-none' />
            <div className='absolute -bottom-32 -left-32 w-96 h-96 bg-emerald-500/10 blur-[100px] rounded-full pointer-events-none' />

            <div className='relative z-10 flex flex-col items-center w-full max-w-4xl'>
              {/* 1. INPUT NODE */}
              <div className='flex flex-col items-center gap-3 relative z-10'>
                  <div className='relative w-16 h-16 rounded-2xl bg-slate-900 border border-slate-700 shadow-[0_0_20px_rgba(0,0,0,0.5)] flex items-center justify-center shrink-0'>
                      <div className="absolute inset-0 bg-yellow-500/10 rounded-2xl animate-pulse" />
                      <Zap className='h-8 w-8 text-yellow-500 drop-shadow-[0_0_10px_rgba(234,179,8,0.5)] relative z-10' />
                  </div>
                  <div className='text-center'>
                      <p className='text-[10px] font-black uppercase tracking-widest text-slate-400 mb-1'>Input Optik Masuk</p>
                      <p className='text-3xl font-black font-mono tracking-tighter'>
                          {inputPower} <span className='text-sm font-bold text-slate-600'>dBm</span>
                      </p>
                  </div>
              </div>

              {/* Line down to Ratio */}
              <div className='w-0.5 h-12 border-l-2 border-dashed border-slate-700/80 relative z-10' />

              {/* 2. RATIO NODE */}
              <div className='inline-flex flex-col items-center bg-slate-900 border border-slate-700 rounded-2xl p-4 shadow-lg relative z-10'>
                  <p className='text-[10px] font-black uppercase tracking-widest text-slate-500 mb-1'>FBT Ratio Splitter</p>
                  <p className='text-2xl font-black font-mono text-white tracking-widest'>
                      {tapPercent} <span className="text-slate-500 mx-1">/</span> {thruPercent}
                  </p>
              </div>

              {/* SPLIT TO BRANCHES */}
              <div className='flex w-full max-w-3xl relative z-10 mt-8'>
                  {/* Center vertical connector to horizontal line */}
                  <div className='absolute -top-8 left-1/2 w-0.5 h-8 border-l-2 border-dashed border-slate-700/80 -translate-x-1/2' />

                  {/* TAP BRANCH (LEFT) */}
                  <div className='flex-1 flex flex-col items-center relative px-1 sm:px-2 pt-8'>
                      {/* Connector from center to branch */}
                      <div className='absolute top-0 right-0 w-[50%] h-8 border-t-2 border-l-2 border-dashed border-slate-700/80 rounded-tl-xl' />
                      
                      <div className={cn('flex flex-col items-center text-center rounded-2xl border p-3 sm:p-4 shadow-inner transition-all w-full max-w-[200px] relative z-10', odpConnection === 'TAP' ? 'border-primary bg-primary/10 shadow-[0_0_20px_rgba(var(--primary),0.1)]' : 'border-slate-800 bg-slate-900/50')}>
                          <p className={cn('text-[9px] sm:text-[10px] font-black uppercase tracking-wider mb-2', odpConnection === 'TAP' ? 'text-primary' : 'text-slate-500')}>Output 1 ({tapPercent}%)</p>
                          {odpConnection === 'TAP' ? (
                              <Badge className="mb-2 bg-primary text-[8px] sm:text-[9px] uppercase font-black px-2 py-0">Diambil</Badge>
                          ) : (
                              <Badge className="mb-2 opacity-0 text-[8px] sm:text-[9px] uppercase font-black pointer-events-none select-none px-2 py-0">_</Badge>
                          )}
                          <p className={cn('text-xl sm:text-2xl font-black font-mono', odpConnection === 'TAP' ? 'text-white' : 'text-slate-400')}>{calculations.tapOutput} <span className="text-xs sm:text-sm">dBm</span></p>
                          <p className="text-[8px] sm:text-[9px] font-mono text-slate-500 mt-1">Loss: -{calculations.tapLoss} dB</p>
                      </div>

                      {/* Continuation of TAP */}
                      {odpConnection === 'TAP' ? (
                          <div className='flex flex-col items-center w-full relative z-10'>
                              <div className='w-0.5 h-10 sm:h-12 border-l-2 border-dashed border-primary' />
                              <div className='bg-primary/20 border-primary border rounded-2xl p-3 sm:p-4 shadow-[0_0_15px_rgba(var(--primary),0.1)] text-center w-full max-w-[200px]'>
                                  <p className='text-[9px] sm:text-[10px] font-black uppercase tracking-widest mb-1 text-primary'>PLC Lokal</p>
                                  <p className='text-xl sm:text-2xl font-black font-mono text-white tracking-widest'>1:{localSplitter}</p>
                                  <p className='text-[8px] sm:text-[9px] font-mono mt-1 text-primary/70'>Loss: -{calculations.splitterLoss} dB</p>
                              </div>
                              <div className='w-0.5 h-10 sm:h-12 border-l-2 border-dashed border-primary' />
                              <div className={cn('border rounded-2xl sm:rounded-3xl p-4 sm:p-5 shadow-2xl relative overflow-hidden w-full max-w-[200px] text-center', isLowSignal ? 'border-red-500/50 bg-red-500/10' : 'border-emerald-500/50 bg-emerald-500/10')}>
                                  <div className={cn("absolute inset-0 opacity-20", isLowSignal ? "bg-red-500" : "bg-emerald-500")} />
                                  <p className={cn('text-[9px] sm:text-[10px] font-black uppercase tracking-widest mb-2 relative z-10', isLowSignal ? 'text-red-400' : 'text-emerald-400')}>Drop Sinyal</p>
                                  <div className="flex items-center justify-center gap-1.5 sm:gap-2 relative z-10">
                                       {isLowSignal ? <ShieldAlert className="h-4 w-4 sm:h-5 sm:w-5 text-red-500 animate-pulse" /> : <CheckCircle2 className="h-4 w-4 sm:h-5 sm:w-5 text-emerald-500" />}
                                      <p className={cn("text-3xl sm:text-4xl font-black font-mono tracking-tighter", isLowSignal ? "text-red-400" : "text-white")}>
                                          {calculations.finalOdpOutput}
                                      </p>
                                  </div>
                              </div>
                          </div>
                      ) : (
                          <div className='flex flex-col items-center w-full relative z-10'>
                              <div className='w-0.5 h-10 sm:h-12 border-l-2 border-dashed border-slate-700/80' />
                              <div className='bg-slate-900/80 border border-slate-700/80 rounded-2xl p-3 sm:p-4 shadow-lg text-center w-full max-w-[200px]'>
                                  <p className='text-[9px] sm:text-[10px] font-black uppercase tracking-widest text-slate-500 mb-1'>Output 1</p>
                                  <p className='text-xl sm:text-2xl font-black font-mono text-slate-400'>{calculations.tapOutput} <span className="text-xs sm:text-sm text-slate-500">dBm</span></p>
                                  <p className='text-[8px] sm:text-[9px] text-slate-500 mt-1'>(Diteruskan)</p>
                              </div>
                          </div>
                      )}
                  </div>

                  {/* THRU BRANCH (RIGHT) */}
                  <div className='flex-1 flex flex-col items-center relative px-1 sm:px-2 pt-8'>
                      {/* Connector from center to branch */}
                      <div className='absolute top-0 left-0 w-[50%] h-8 border-t-2 border-r-2 border-dashed border-slate-700/80 rounded-tr-xl' />
                      
                      <div className={cn('flex flex-col items-center text-center rounded-2xl border p-3 sm:p-4 shadow-inner transition-all w-full max-w-[200px] relative z-10', odpConnection === 'THRU' ? 'border-emerald-500 bg-emerald-500/10 shadow-[0_0_20px_rgba(16,185,129,0.1)]' : 'border-slate-800 bg-slate-900/50')}>
                          <p className={cn('text-[9px] sm:text-[10px] font-black uppercase tracking-wider mb-2', odpConnection === 'THRU' ? 'text-emerald-500' : 'text-slate-500')}>Output 2 ({thruPercent}%)</p>
                          {odpConnection === 'THRU' ? (
                              <Badge className="mb-2 bg-emerald-500 text-[8px] sm:text-[9px] uppercase font-black px-2 py-0 hover:bg-emerald-600">Diambil</Badge>
                          ) : (
                              <Badge className="mb-2 opacity-0 text-[8px] sm:text-[9px] uppercase font-black pointer-events-none select-none px-2 py-0">_</Badge>
                          )}
                          <p className={cn('text-xl sm:text-2xl font-black font-mono', odpConnection === 'THRU' ? 'text-white' : 'text-slate-400')}>{calculations.thruOutput} <span className="text-xs sm:text-sm">dBm</span></p>
                          <p className="text-[8px] sm:text-[9px] font-mono text-slate-500 mt-1">Loss: -{calculations.thruLoss} dB</p>
                      </div>

                      {/* Continuation of THRU */}
                      {odpConnection === 'THRU' ? (
                          <div className='flex flex-col items-center w-full relative z-10'>
                              <div className='w-0.5 h-10 sm:h-12 border-l-2 border-dashed border-emerald-500' />
                              <div className='bg-emerald-500/20 border-emerald-500 border rounded-2xl p-3 sm:p-4 shadow-[0_0_15px_rgba(16,185,129,0.1)] text-center w-full max-w-[160px] sm:max-w-[180px]'>
                                  <p className='text-[9px] sm:text-[10px] font-black uppercase tracking-widest mb-1 text-emerald-500'>PLC Lokal</p>
                                  <p className='text-xl sm:text-2xl font-black font-mono text-white tracking-widest'>1:{localSplitter}</p>
                                  <p className='text-[8px] sm:text-[9px] font-mono mt-1 text-emerald-500/70'>Loss: -{calculations.splitterLoss} dB</p>
                              </div>
                              <div className='w-0.5 h-10 sm:h-12 border-l-2 border-dashed border-emerald-500' />
                              <div className={cn('border rounded-2xl sm:rounded-3xl p-4 sm:p-5 shadow-2xl relative overflow-hidden w-full max-w-[200px] sm:max-w-[220px] text-center', isLowSignal ? 'border-red-500/50 bg-red-500/10' : 'border-emerald-500/50 bg-emerald-500/10')}>
                                  <div className={cn("absolute inset-0 opacity-20", isLowSignal ? "bg-red-500" : "bg-emerald-500")} />
                                  <p className={cn('text-[9px] sm:text-[10px] font-black uppercase tracking-widest mb-2 relative z-10', isLowSignal ? 'text-red-400' : 'text-emerald-400')}>Drop Sinyal</p>
                                  <div className="flex items-center justify-center gap-1.5 sm:gap-2 relative z-10">
                                       {isLowSignal ? <ShieldAlert className="h-4 w-4 sm:h-5 sm:w-5 text-red-500 animate-pulse" /> : <CheckCircle2 className="h-4 w-4 sm:h-5 sm:w-5 text-emerald-500" />}
                                      <p className={cn("text-3xl sm:text-4xl font-black font-mono tracking-tighter", isLowSignal ? "text-red-400" : "text-white")}>
                                          {calculations.finalOdpOutput}
                                      </p>
                                  </div>
                              </div>
                          </div>
                      ) : (
                          <div className='flex flex-col items-center w-full relative z-10'>
                              <div className='w-0.5 h-10 sm:h-12 border-l-2 border-dashed border-slate-700/80' />
                              <div className='bg-slate-900/80 border border-slate-700/80 rounded-2xl p-3 sm:p-4 shadow-lg text-center w-full max-w-[200px]'>
                                  <p className='text-[9px] sm:text-[10px] font-black uppercase tracking-widest text-slate-500 mb-1'>Output 2</p>
                                  <p className='text-xl sm:text-2xl font-black font-mono text-slate-400'>{calculations.thruOutput} <span className="text-xs sm:text-sm text-slate-500">dBm</span></p>
                                  <p className='text-[8px] sm:text-[9px] text-slate-500 mt-1'>(Diteruskan)</p>
                              </div>
                          </div>
                      )}
                  </div>
              </div>
            </div>
          </div>
        </div>
      </Main>
    </>
  )
}
