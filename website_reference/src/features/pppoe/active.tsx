import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { RouterSelector } from '@/components/router-selector'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { ThemeSwitch } from '@/components/theme-switch'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Wifi, AlertTriangle } from 'lucide-react'
import { PPPoESubNav } from './components/pppoe-sub-nav'
import { PPPoEActiveTable } from './components/active-table'
import { usePPPoEData } from './hooks/use-pppoe-data'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'

export function PPPoEActivePage() {
  const { pppActive, pppProfiles, isActiveLoading, connectionError } = usePPPoEData()

  return (
    <>
      <Header fixed>
        <div className='me-auto flex items-center gap-2'>
          <div className='p-2 bg-green-100 dark:bg-green-900/30 rounded-lg'>
            <Wifi className='h-5 w-5 text-green-600' />
          </div>
          <h1 className='text-lg font-bold'>PPPoE — Active Connections</h1>
        </div>
        <RouterSelector />
        <ThemeSwitch />
        <ProfileDropdown />
      </Header>

      <Main className='space-y-4' fluid>
        <PPPoESubNav active='/pppoe/active' />

        {connectionError && (
          <Alert variant='destructive' className='border-red-500 bg-red-500/10 text-red-600 dark:text-red-400'>
            <AlertTriangle className='h-4 w-4 text-red-500 animate-pulse' />
            <AlertTitle className='font-bold uppercase tracking-wider text-xs'>MikroTik Connection Failed</AlertTitle>
            <AlertDescription className='text-xs font-semibold'>
              {connectionError}. Silakan periksa kembali jaringan VPN atau status fisik router Anda.
            </AlertDescription>
          </Alert>
        )}

        <Card className='border-t-4 border-t-green-500 shadow-lg border-x-0 border-b-0 rounded-none md:rounded-xl md:border'>
          <CardHeader className='pb-3'>
            <div className='flex items-center justify-between'>
              <div>
                <CardTitle className='text-xl flex items-center gap-2'>
                  <Wifi className='w-5 h-5 text-green-500' />
                  Active PPPoE Connections
                </CardTitle>
                <CardDescription>Daftar user yang sedang terhubung ke router secara real-time.</CardDescription>
              </div>
              <Badge className='text-sm px-3 py-1 bg-green-500/20 text-green-600 dark:text-green-400 hover:bg-green-500/30 border-0'>
                {isActiveLoading ? '...' : `${pppActive.length} Online`}
              </Badge>
            </div>
          </CardHeader>
          <CardContent>
            <PPPoEActiveTable
              data={pppActive}
              isLoading={isActiveLoading}
              profiles={pppProfiles.map((p: any) => p.name)}
            />
          </CardContent>
        </Card>
      </Main>
    </>
  )
}
