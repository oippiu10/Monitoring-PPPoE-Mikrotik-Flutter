import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { useRouterStore } from '@/stores/router-store'
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from '@/components/ui/sheet'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { Input } from '@/components/ui/input'
import { NotebookText, Trash2, Send, Loader2, Clock, Search, Pencil, X, Save } from 'lucide-react'
import { toast } from 'sonner'
import { format, parseISO } from 'date-fns'
import { id } from 'date-fns/locale'

export function FinanceNotesSheet() {
  const { activeRouter } = useRouterStore()
  const queryClient = useQueryClient()
  const [open, setOpen] = useState(false)
  const [noteContent, setNoteContent] = useState('')
  const [editingId, setEditingId] = useState<number | null>(null)
  const [searchQuery, setSearchQuery] = useState('')

  const currentRouterId = activeRouter?.software_id || activeRouter?.id || 'global'

  const { data: notes = [], isLoading } = useQuery({
    queryKey: ['finance_notes', currentRouterId],
    queryFn: async () => {
      const res = await api.get('/finance_notes.php', {
        params: { action: 'list', router_id: currentRouterId }
      })
      return res.data?.data || []
    },
    enabled: open,
  })

  const addMutation = useMutation({
    mutationFn: async () => {
      const payload = {
        action: 'add',
        router_id: currentRouterId,
        content: noteContent
      }
      const res = await api.post('/finance_notes.php', payload)
      return res.data
    },
    onSuccess: (d) => {
      if (d.success) {
        toast.success(d.message || 'Catatan tersimpan')
        setNoteContent('')
        queryClient.invalidateQueries({ queryKey: ['finance_notes'] })
      } else {
        toast.error(d.message || 'Gagal menyimpan')
      }
    }
  })

  const deleteMutation = useMutation({
    mutationFn: async (noteId: number) => {
      const payload = {
        action: 'delete',
        router_id: currentRouterId,
        id: noteId
      }
      const res = await api.post('/finance_notes.php', payload)
      return res.data
    },
    onSuccess: (d) => {
      if (d.success) {
        toast.success('Catatan dihapus')
        if (editingId) {
          setEditingId(null)
          setNoteContent('')
        }
        queryClient.invalidateQueries({ queryKey: ['finance_notes'] })
      } else {
        toast.error(d.message || 'Gagal menghapus')
      }
    }
  })

  const editMutation = useMutation({
    mutationFn: async () => {
      const payload = {
        action: 'edit',
        router_id: currentRouterId,
        id: editingId,
        content: noteContent
      }
      const res = await api.post('/finance_notes.php', payload)
      return res.data
    },
    onSuccess: (d) => {
      if (d.success) {
        toast.success(d.message || 'Catatan diperbarui')
        setNoteContent('')
        setEditingId(null)
        queryClient.invalidateQueries({ queryKey: ['finance_notes'] })
      } else {
        toast.error(d.message || 'Gagal memperbarui')
      }
    }
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!noteContent.trim()) return
    if (editingId) {
      editMutation.mutate()
    } else {
      addMutation.mutate()
    }
  }

  const filteredNotes = notes.filter((n: any) => 
    n.content.toLowerCase().includes(searchQuery.toLowerCase())
  )

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button variant="outline" size="sm" className="h-8 gap-2 text-xs font-bold border-indigo-200 text-indigo-600 bg-indigo-50 hover:bg-indigo-100 hover:text-indigo-700 dark:border-indigo-900/50 dark:bg-indigo-950/30 dark:text-indigo-400">
          <NotebookText className="h-4 w-4" />
          <span className="hidden sm:inline">Catatan</span>
        </Button>
      </SheetTrigger>
      
      <SheetContent className="w-full sm:max-w-[540px] border-l border-border/50 shadow-2xl flex flex-col p-0">
        <SheetHeader className="p-6 pb-4 border-b border-border/50 bg-muted/20">
          <SheetTitle className="flex items-center gap-2">
            <NotebookText className="h-5 w-5 text-indigo-500" />
            Catatan Keuangan
          </SheetTitle>
          <p className="text-xs text-muted-foreground mt-1">
            Simpan janji bayar, target, atau anomali dana di sini.
          </p>
        </SheetHeader>

        {/* Input Area dengan Toolbar */}
        <div className="p-4 border-b border-border/50 bg-background/50 backdrop-blur">
          <form onSubmit={handleSubmit} className="space-y-2">
            {/* Toolbar Mini */}
            <div className="flex items-center gap-1 bg-muted/50 p-1.5 rounded-lg border border-border/50 w-max">
              <Button
                type="button" variant="ghost" size="icon" className="h-7 w-7 rounded-md hover:bg-background"
                title="Bold"
                onClick={() => {
                  setNoteContent(prev => prev + '**Teks Tebal** ');
                }}
              >
                <span className="font-serif font-bold text-sm">B</span>
              </Button>
              <Button
                type="button" variant="ghost" size="icon" className="h-7 w-7 rounded-md hover:bg-background"
                title="Italic"
                onClick={() => {
                  setNoteContent(prev => prev + '_Teks Miring_ ');
                }}
              >
                <span className="font-serif italic text-sm">I</span>
              </Button>
              <div className="w-px h-4 bg-border mx-1"></div>
              <Button
                type="button" variant="ghost" size="icon" className="h-7 w-7 rounded-md hover:bg-background"
                title="Bullet List"
                onClick={() => {
                  setNoteContent(prev => prev + (prev.endsWith('\n') || prev === '' ? '' : '\n') + '- ');
                }}
              >
                <span className="font-bold text-lg leading-none -mt-1">•</span>
              </Button>
              <Button
                type="button" variant="ghost" size="icon" className="h-7 w-7 rounded-md hover:bg-background"
                title="Number List"
                onClick={() => {
                  setNoteContent(prev => {
                    const lines = prev.split('\n');
                    let lastContentLine = '';
                    for (let i = lines.length - 1; i >= 0; i--) {
                      if (lines[i].trim() !== '') {
                        lastContentLine = lines[i];
                        break;
                      }
                    }
                    const match = lastContentLine.match(/^(\d+)\.\s/);
                    let nextNum = 1;
                    if (match) nextNum = parseInt(match[1], 10) + 1;
                    
                    return prev + (prev.endsWith('\n') || prev === '' ? '' : '\n') + nextNum + '. ';
                  });
                }}
              >
                <span className="font-bold text-xs">1.</span>
              </Button>
            </div>

            <div className="relative">
              <Textarea
                placeholder="Ketik catatan di sini..."
                className="resize-none pr-12 min-h-[100px] bg-background text-sm focus-visible:ring-indigo-500 rounded-xl"
                value={noteContent}
                onChange={(e) => setNoteContent(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
                    e.preventDefault()
                    handleSubmit(e)
                  }
                }}
              />
              <div className="absolute bottom-2 right-2 flex gap-1">
                {editingId && (
                  <Button
                    type="button"
                    size="icon"
                    variant="outline"
                    className="h-8 w-8 rounded-lg hover:bg-rose-100 hover:text-rose-600 dark:hover:bg-rose-900/30 border-rose-200"
                    onClick={() => {
                      setEditingId(null)
                      setNoteContent('')
                    }}
                    title="Batal Edit"
                  >
                    <X className="h-4 w-4" />
                  </Button>
                )}
                <Button
                  type="submit"
                  size="icon"
                  disabled={!noteContent.trim() || addMutation.isPending || editMutation.isPending}
                  className="h-8 w-8 rounded-lg bg-indigo-500 hover:bg-indigo-600 text-white"
                >
                  {(addMutation.isPending || editMutation.isPending) ? <Loader2 className="h-4 w-4 animate-spin" /> : (editingId ? <Save className="h-4 w-4" /> : <Send className="h-4 w-4" />)}
                </Button>
              </div>
            </div>
            <p className="text-[10px] text-muted-foreground ml-1">Tips: Gunakan <b>**tebal**</b>, <i>_miring_</i>. Tekan <b>Ctrl+Enter</b> untuk menyimpan.</p>
          </form>
        </div>

        {/* Search */}
        <div className="px-4 pt-4 bg-slate-50/50 dark:bg-background/95">
          <div className="relative">
            <Search className="absolute left-2.5 top-2 h-4 w-4 text-muted-foreground" />
            <Input 
              placeholder="Cari catatan..." 
              className="pl-8 h-8 text-xs bg-white dark:bg-muted/30"
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
            />
          </div>
        </div>

        {/* Notes List */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-slate-50/50 dark:bg-background/95">
          {isLoading ? (
            <div className="flex justify-center py-8">
              <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
            </div>
          ) : filteredNotes.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-center opacity-50">
              <NotebookText className="h-12 w-12 mb-3 text-muted-foreground" />
              <p className="text-sm font-medium">{searchQuery ? 'Catatan tidak ditemukan' : 'Belum ada catatan'}</p>
              <p className="text-xs text-muted-foreground">{searchQuery ? 'Coba kata kunci pencarian yang lain' : 'Catatan yang Anda buat akan muncul di sini'}</p>
            </div>
          ) : (
            filteredNotes.map((note: any) => {
              // Palet warna modern untuk sticky notes
              const colors = [
                'bg-gradient-to-br from-amber-50 to-orange-100/80 text-amber-950 dark:from-amber-950/40 dark:to-orange-900/20 dark:text-amber-200 border-amber-200/50 dark:border-amber-700/30',
                'bg-gradient-to-br from-blue-50 to-indigo-100/80 text-blue-950 dark:from-blue-950/40 dark:to-indigo-900/20 dark:text-blue-200 border-blue-200/50 dark:border-blue-700/30',
                'bg-gradient-to-br from-emerald-50 to-teal-100/80 text-emerald-950 dark:from-emerald-950/40 dark:to-teal-900/20 dark:text-emerald-200 border-emerald-200/50 dark:border-emerald-700/30',
                'bg-gradient-to-br from-purple-50 to-fuchsia-100/80 text-purple-950 dark:from-purple-950/40 dark:to-fuchsia-900/20 dark:text-purple-200 border-purple-200/50 dark:border-purple-700/30',
                'bg-gradient-to-br from-rose-50 to-pink-100/80 text-rose-950 dark:from-rose-950/40 dark:to-pink-900/20 dark:text-rose-200 border-rose-200/50 dark:border-rose-700/30'
              ];
              const colorClass = colors[note.id % colors.length];

              // Fungsi mini parser rich-text sederhana
              const renderRichText = (text: string) => {
                const lines = text.split('\n');
                return lines.map((line, i) => {
                  let parsedLine = line;
                  let isBullet = false;
                  let isNumber = false;
                  let prefix = '';

                  if (line.match(/^[-*]\s+(.*)/)) {
                    isBullet = true;
                    parsedLine = line.replace(/^[-*]\s+/, '');
                  } else if (line.match(/^(\d+)\.\s+(.*)/)) {
                    isNumber = true;
                    const match = line.match(/^(\d+)\.\s+(.*)/);
                    prefix = match?.[1] + '.';
                    parsedLine = match?.[2] || '';
                  }

                  // Bold & Italic parser
                  const parts = parsedLine.split(/(\*\*.*?\*\*|__.*?__|_[^_]+_|\*[^*]+\*)/g);
                  const elements = parts.map((part, j) => {
                    if (part.startsWith('**') && part.endsWith('**')) return <strong key={j} className="font-extrabold tracking-tight">{part.slice(2, -2)}</strong>;
                    if (part.startsWith('__') && part.endsWith('__')) return <strong key={j} className="font-extrabold tracking-tight">{part.slice(2, -2)}</strong>;
                    if (part.startsWith('_') && part.endsWith('_')) return <em key={j} className="italic opacity-90">{part.slice(1, -1)}</em>;
                    if (part.startsWith('*') && part.endsWith('*')) return <em key={j} className="italic opacity-90">{part.slice(1, -1)}</em>;
                    return <span key={j}>{part}</span>;
                  });

                  if (isBullet) {
                    return (
                      <div key={i} className="flex gap-2.5 items-start ml-1 mt-1">
                        <span className="text-lg leading-none opacity-50 -mt-px">•</span>
                        <span className="flex-1">{elements}</span>
                      </div>
                    );
                  }
                  if (isNumber) {
                    return (
                      <div key={i} className="flex gap-2 items-start ml-1 mt-1">
                        <span className="font-black text-[11px] mt-[3px] opacity-60 min-w-[16px]">{prefix}</span>
                        <span className="flex-1">{elements}</span>
                      </div>
                    );
                  }
                  return <div key={i} className="min-h-[20px]">{elements}</div>;
                });
              };

              return (
                <div key={note.id} className={`group relative rounded-2xl p-5 border shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all duration-300 ${colorClass}`}>
                  {/* Decorative corner fold */}
                  <div className="absolute top-0 right-0 w-8 h-8 overflow-hidden rounded-tr-2xl">
                    <div className="absolute top-0 right-0 w-16 h-16 bg-white/20 dark:bg-black/20 -rotate-45 transform origin-top-right shadow-[0_1px_3px_rgba(0,0,0,0.1)] backdrop-blur-md"></div>
                  </div>
                  
                  <div className="flex items-start justify-between gap-4 relative z-10">
                    <div className="flex-1 space-y-3">
                      <div className="flex items-center gap-1.5 opacity-60">
                        <Clock className="h-3.5 w-3.5" />
                        <span className="text-[10px] font-bold uppercase tracking-widest">
                          {format(parseISO(note.created_at), 'dd MMM yyyy, HH:mm', { locale: id })}
                        </span>
                      </div>
                      <div className="text-[13px] font-medium leading-relaxed tracking-wide">
                        {renderRichText(note.content)}
                      </div>
                    </div>
                    
                    <div className="flex gap-1 shrink-0">
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => {
                          setEditingId(note.id)
                          setNoteContent(note.content)
                        }}
                        className="h-8 w-8 opacity-0 group-hover:opacity-100 transition-opacity bg-black/5 hover:bg-indigo-500 hover:text-white dark:bg-white/10 dark:hover:bg-indigo-600 rounded-full"
                        title="Edit Catatan"
                      >
                        <Pencil className="h-3.5 w-3.5" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => {
                          if(window.confirm('Hapus catatan ini?')) {
                            deleteMutation.mutate(note.id)
                          }
                        }}
                        className="h-8 w-8 opacity-0 group-hover:opacity-100 transition-opacity bg-black/5 hover:bg-rose-500 hover:text-white dark:bg-white/10 dark:hover:bg-rose-600 rounded-full"
                        title="Hapus Catatan"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </Button>
                    </div>
                  </div>
                </div>
              )
            })
          )}
        </div>
      </SheetContent>
    </Sheet>
  )
}
