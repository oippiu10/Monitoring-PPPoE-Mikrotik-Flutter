import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { useRouterStore } from '@/stores/router-store'
import { Header } from '@/components/layout/header'
import { Main } from '@/components/layout/main'
import { ProfileDropdown } from '@/components/profile-dropdown'
import { ThemeSwitch } from '@/components/theme-switch'
import { RouterSelector } from '@/components/router-selector'
import { Button } from '@/components/ui/button'
import { Plus, Server } from 'lucide-react'
import { ODCTable } from './components/odc-table'
import { ODCMutateDialog } from './components/odc-mutate-drawer'
import { ODPSubNav } from '../odp/components/odp-sub-nav'
import { usePermission } from '@/lib/permissions'

export default function ODCPage() {
  const { activeRouter } = useRouterStore()
  const permissions = usePermission()
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false)

  const { data, isLoading } = useQuery({
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

  return (
    <>
      <Header fixed>
        <div className='me-auto flex items-center gap-2'>
            <div className="p-2 bg-primary/10 rounded-lg">
                <Server className="h-5 w-5 text-primary" />
            </div>
            <h1 className='text-lg font-bold'>Manajemen ODC & ODP</h1>
        </div>
        <RouterSelector />
        <ThemeSwitch />
        <ProfileDropdown />
      </Header>

      <Main className='flex flex-col gap-4' fluid>
        <ODPSubNav active='/odp/odc' />
        <div className='flex items-center justify-between gap-4'>
          <div>
            <h2 className='text-2xl font-bold tracking-tight'>Daftar ODC</h2>
            <p className='text-muted-foreground'>
                Kelola Optical Distribution Cabinet (ODC) sebagai sumber pembagi utama sebelum ODP.
            </p>
          </div>
          {permissions.canManageCustomers && (
            <div className='flex flex-wrap gap-2'>
              <Button size='sm' className='bg-amber-600 hover:bg-amber-700 text-white' onClick={() => setIsAddDialogOpen(true)} disabled={!activeRouter}>
                <Plus className='mr-2 h-4 w-4' /> Tambah ODC
              </Button>
            </div>
          )}
        </div>

        <div className='flex-1 overflow-auto'>
          <ODCTable
            data={data || []}
            isLoading={isLoading}
          />
        </div>
      </Main>

      <ODCMutateDialog 
        isOpen={isAddDialogOpen}
        onClose={() => setIsAddDialogOpen(false)}
      />
    </>
  )
}
