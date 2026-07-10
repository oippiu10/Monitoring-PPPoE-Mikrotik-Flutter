export interface FiberColorInfo {
  name: string
  code: string
}

export interface FiberMapResult {
  tube: FiberColorInfo & { index: number }
  core: FiberColorInfo & { index: number }
}

export const FIBER_COLORS: FiberColorInfo[] = [
  { name: 'Biru', code: '#1a6fcc' },
  { name: 'Oranye', code: '#f97316' },
  { name: 'Hijau', code: '#16a34a' },
  { name: 'Cokelat', code: '#92400e' },
  { name: 'Abu-abu', code: '#6b7280' },
  { name: 'Putih', code: '#e5e7eb' },
  { name: 'Merah', code: '#dc2626' },
  { name: 'Hitam', code: '#111827' },
  { name: 'Kuning', code: '#eab308' },
  { name: 'Ungu', code: '#7c3aed' },
  { name: 'Pink', code: '#ec4899' },
  { name: 'Toska', code: '#0d9488' },
]

/** Opsi total core kabel yang tersedia */
export const CABLE_CORE_OPTIONS = [1, 2, 4, 6, 8, 12, 24, 48, 96, 144, 288] as const

/** Hitung jumlah tube dari total core kabel */
export function getTubeCount(totalCores: number): number {
  if (totalCores <= 12) return 1
  return Math.ceil(totalCores / 12)
}

/** 
 * Hitung core_number dari pilihan tube dan core.
 * tubeIndex: 0-based, coreIndex: 0-based
 */
export function getCoreNumberFromSelection(tubeIndex: number, coreIndex: number): number {
  return tubeIndex * 12 + coreIndex + 1
}

/**
 * Reverse lookup: dari core_number → { tubeIndex (0-based), coreIndex (0-based) }
 * Digunakan saat edit data lama agar picker menampilkan nilai yang sudah terpilih.
 */
export function getSelectionFromCoreNumber(coreNumber: number): { tubeIndex: number; coreIndex: number } {
  const tubeIndex = Math.ceil(coreNumber / 12) - 1
  const coreIndex = (coreNumber - 1) % 12
  return { tubeIndex, coreIndex }
}

/**
 * Infer total cable size dari core_number. 
 * Mengembalikan ukuran kabel paling kecil yang bisa menampung core tersebut.
 */
export function inferCableSizeFromCoreNumber(coreNumber: number): number {
  for (const size of CABLE_CORE_OPTIONS) {
    if (coreNumber <= size) return size
  }
  return 288
}

export function getFiberColors(coreNumber: number | null | undefined): FiberMapResult | null {
  if (coreNumber === null || coreNumber === undefined || isNaN(coreNumber) || coreNumber < 1) {
    return null
  }

  const tubeIndex = Math.ceil(coreNumber / 12) - 1
  const coreIndex = (coreNumber - 1) % 12

  // Modulo in case the number of tubes exceeds 12 (though standard cables are up to 144 core, i.e. 12 tubes)
  const tubeColor = FIBER_COLORS[tubeIndex % 12]
  const coreColor = FIBER_COLORS[coreIndex]

  return {
    tube: {
      name: tubeColor.name,
      code: tubeColor.code,
      index: tubeIndex + 1
    },
    core: {
      name: coreColor.name,
      code: coreColor.code,
      index: coreIndex + 1
    }
  }
}
