import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { RouterSelector } from '@/components/router-selector'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { ThemeSwitch } from '@/components/theme-switch'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { WifiOff, AlertTriangle } from 'lucide-react'
import { PPPoESubNav } from './components/pppoe-sub-nav'
import { PPPoEOfflineTable } from './components/offline-table'
import { usePPPoEData } from './hooks/use-pppoe-data'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'

export function PPPoEOfflinePage() {
  const { offlineUsers, pppProfiles, isSecretsLoading, isActiveLoading, connectionError } = usePPPoEData()

  return (
    <>
      <Header fixed>
        <div className='me-auto flex items-center gap-2'>
          <div className='p-2 bg-red-100 dark:bg-red-900/30 rounded-lg'>
            <WifiOff className='h-5 w-5 text-red-500' />
          </div>
          <h1 className='text-lg font-bold'>PPPoE — Offline Users</h1>
        </div>
        <RouterSelector />
        <ThemeSwitch />
        <ProfileDropdown />
      </Header>

      <Main className='space-y-4' fluid>
        <PPPoESubNav active='/pppoe/offline' />

        {connectionError && (
          <Alert variant='destructive' className='border-red-500 bg-red-500/10 text-red-600 dark:text-red-400'>
            <AlertTriangle className='h-4 w-4 text-red-500 animate-pulse' />
            <AlertTitle className='font-bold uppercase tracking-wider text-xs'>MikroTik Connection Failed</AlertTitle>
            <AlertDescription className='text-xs font-semibold'>
              {connectionError}. Silakan periksa kembali jaringan VPN atau status fisik router Anda.
            </AlertDescription>
          </Alert>
        )}

        <Card className='border-t-4 border-t-destructive shadow-lg border-x-0 border-b-0 rounded-none md:rounded-xl md:border'>
          <CardHeader className='pb-3'>
            <div className='flex items-center justify-between'>
              <div>
                <CardTitle className='text-xl flex items-center gap-2'>
                  <WifiOff className='w-5 h-5 text-destructive' />
                  Offline PPPoE Users
                </CardTitle>
                <CardDescription>Daftar user yang saat ini sedang tidak terhubung (offline).</CardDescription>
              </div>
              <Badge variant='destructive' className='text-sm px-3 py-1 bg-destructive/20 text-destructive hover:bg-destructive/30 border-0'>
                {(isSecretsLoading || isActiveLoading) ? '...' : `${offlineUsers.length} Offline`}
              </Badge>
            </div>
          </CardHeader>
          <CardContent>
            <PPPoEOfflineTable
              data={offlineUsers}
              isLoading={isSecretsLoading || isActiveLoading}
              profiles={pppProfiles.map((p: any) => p.name)}
            />
          </CardContent>
        </Card>
      </Main>
    </>
  )
}
