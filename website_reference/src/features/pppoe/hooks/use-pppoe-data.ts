/**
 * Shared hook untuk semua halaman PPPoE
 * Mencegah duplikasi fetch data antara halaman
 */
import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { useRouterStore } from '@/stores/router-store'

export function usePPPoEData() {
  const { activeRouter } = useRouterStore()

  const { 
    data: pppActive, 
    isLoading: isActiveLoading, 
    isError: isActiveError, 
    error: activeError 
  } = useQuery({
    queryKey: ['ppp-active', activeRouter?.id],
    queryFn: async () => {
      const res = await api.get('/mikrotik_live.php', {
        params: { router_id: activeRouter?.id, cmd: 'ppp_active' }
      })
      if (res.data && res.data.success === false) {
        throw new Error(res.data.message || 'Gagal mengambil data koneksi aktif MikroTik')
      }
      return res.data.data || []
    },
    enabled: !!activeRouter,
    refetchInterval: 3000,
    retry: 1,
  })

  const { 
    data: pppSecrets, 
    isLoading: isSecretsLoading, 
    isError: isSecretsError, 
    error: secretsError 
  } = useQuery({
    queryKey: ['ppp-secret', activeRouter?.id],
    queryFn: async () => {
      const res = await api.get('/mikrotik_live.php', {
        params: { router_id: activeRouter?.id, cmd: 'ppp_secret' }
      })
      if (res.data && res.data.success === false) {
        throw new Error(res.data.message || 'Gagal mengambil data Secrets PPPoE')
      }
      return res.data.data || []
    },
    enabled: !!activeRouter,
    refetchInterval: 60000,
    retry: 1,
  })

  const { 
    data: pppProfiles, 
    isLoading: isProfilesLoading, 
    isError: isProfilesError, 
    error: profilesError 
  } = useQuery({
    queryKey: ['ppp-profile', activeRouter?.id],
    queryFn: async () => {
      const res = await api.get('/mikrotik_live.php', {
        params: { router_id: activeRouter?.id, cmd: 'ppp_profile' }
      })
      if (res.data && res.data.success === false) {
        throw new Error(res.data.message || 'Gagal mengambil data Profiles PPPoE')
      }
      return res.data.data || []
    },
    enabled: !!activeRouter,
    refetchInterval: 300000,
    retry: 1,
  })

  const activeNames = useMemo(
    () => new Set<string>((pppActive || []).map((a: any) => String(a.name))),
    [pppActive]
  )

  const offlineUsers = useMemo(
    () => (pppSecrets || []).filter((s: any) => !activeNames.has(s.name)),
    [pppSecrets, activeNames]
  )

  const profileNames = (pppProfiles || []).map((p: any) => p.name)

  const connectionError = useMemo(() => {
    if (isActiveError) return (activeError as Error)?.message || 'Koneksi ke MikroTik gagal (PPP Active)'
    if (isSecretsError) return (secretsError as Error)?.message || 'Koneksi ke MikroTik gagal (PPP Secret)'
    if (isProfilesError) return (profilesError as Error)?.message || 'Koneksi ke MikroTik gagal (PPP Profile)'
    return null
  }, [isActiveError, isSecretsError, isProfilesError, activeError, secretsError, profilesError])

  return {
    activeRouter,
    pppActive: pppActive || [],
    pppSecrets: pppSecrets || [],
    pppProfiles: pppProfiles || [],
    offlineUsers,
    activeNames,
    profileNames,
    isActiveLoading,
    isSecretsLoading,
    isProfilesLoading,
    connectionError,
  }
}
