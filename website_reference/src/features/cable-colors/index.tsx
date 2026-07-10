import { useQuery } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { useRouterStore } from '@/stores/router-store'
import { CableColorTable } from './components/cable-color-table'
import { ODPSubNav } from '../odp/components/odp-sub-nav'
import { Header } from '@/components/layout/header'
import { Search } from '@/components/search'
import { ThemeSwitch } from '@/components/theme-switch'
import { ProfileDropdown } from '@/components/profile-dropdown'

export default function CableColorsPage() {
  const { activeRouter } = useRouterStore()

  const { data: colors = [], isLoading } = useQuery({
    queryKey: ['cable-colors', activeRouter?.id],
    queryFn: async () => {
      if (!activeRouter?.id) return []
      const res = await api.get(`/cable_colors.php?router_id=${activeRouter.id}`)
      return res.data.data || []
    },
    enabled: !!activeRouter?.id,
  })

  return (
    <>
      <Header fixed>
        <Search />
        <div className='ml-auto flex items-center space-x-4'>
          <ThemeSwitch />
          <ProfileDropdown />
        </div>
      </Header>

      <div className='flex flex-1 flex-col space-y-4 p-4 md:p-6'>
        <div className='flex items-center justify-between space-y-2'>
          <div>
            <h2 className='text-2xl font-black uppercase tracking-wider text-slate-800 dark:text-slate-100'>
              Manajemen Warna Kabel
            </h2>
            <p className='text-xs font-semibold text-muted-foreground'>
              Definisikan dan kelola kategori warna kabel untuk dokumentasi ODC dan ODP Anda
            </p>
          </div>
        </div>

        <ODPSubNav active='/odp/cable-colors' />

        <div className='flex-1 rounded-xl bg-white p-4 shadow-xs dark:bg-slate-900 border dark:border-slate-800'>
          <CableColorTable data={colors} isLoading={isLoading} />
        </div>
      </div>
    </>
  )
}
