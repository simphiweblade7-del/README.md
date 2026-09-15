'use client'

import { useState } from 'react'
import {
  AlignCenter,
  ArrowDownToLine,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  CircleHelp,
  Eye,
  EyeOff,
  Grid3X3,
  ImagePlus,
  Layers3,
  Lock,
  Menu,
  MousePointer2,
  Palette,
  PenTool,
  Plus,
  Redo2,
  RotateCcw,
  Search,
  Shirt,
  Sparkles,
  Square,
  Star,
  Type,
  Undo2,
  Unlock,
  ZoomIn,
} from 'lucide-react'

const colors = [
  { name: 'Ink', value: '#1f2024' },
  { name: 'Cloud', value: '#f3f1ec' },
  { name: 'Cobalt', value: '#455bff' },
  { name: 'Tomato', value: '#f56e59' },
  { name: 'Sage', value: '#8da58d' },
]

const initialLayers = [
  { id: 'mark', name: 'Mountain mark', type: 'Logo', visible: true, locked: false },
  { id: 'wordmark', name: 'Northstar', type: 'Text', visible: true, locked: false },
  { id: 'shirt', name: 'Garment', type: 'Mockup', visible: true, locked: true },
]

export default function Page() {
  const [activeTool, setActiveTool] = useState('select')
  const [selectedLayer, setSelectedLayer] = useState('mark')
  const [layers, setLayers] = useState(initialLayers)
  const [garmentColor, setGarmentColor] = useState(colors[0].value)
  const [side, setSide] = useState<'Front' | 'Back'>('Front')
  const [zoom, setZoom] = useState(72)
  const [toast, setToast] = useState('')

  const flash = (message: string) => {
    setToast(message)
    window.setTimeout(() => setToast(''), 2400)
  }

  const toggleLayer = (id: string, key: 'visible' | 'locked') => {
    setLayers((current) => current.map((layer) => (layer.id === id ? { ...layer, [key]: !layer[key] } : layer)))
  }

  return (
    <main className="studio-shell">
      <header className="topbar">
        <div className="brand-lockup">
          <div className="brand-mark"><Sparkles size={16} /></div>
          <span>loom</span>
        </div>
        <div className="project-title">
          <span className="status-dot" />
          <span>Northstar / capsule 01</span>
          <ChevronDown size={14} />
        </div>
        <div className="top-actions">
          <button className="icon-button subtle" aria-label="Undo"><Undo2 size={16} /></button>
          <button className="icon-button subtle" aria-label="Redo"><Redo2 size={16} /></button>
          <div className="top-divider" />
          <button className="help-button" onClick={() => flash('Shortcuts are coming soon')}> <CircleHelp size={15} /> Help</button>
          <button className="share-button" onClick={() => flash('Design link copied to clipboard')}>Share <ArrowDownToLine size={15} /></button>
          <div className="avatar">AM</div>
        </div>
      </header>

      <div className="workspace">
        <aside className="tool-rail">
          <button className="rail-menu" aria-label="Open menu"><Menu size={18} /></button>
          <div className="rail-divider" />
          {[
            { id: 'select', label: 'Select', icon: MousePointer2 },
            { id: 'text', label: 'Text', icon: Type },
            { id: 'shape', label: 'Shape', icon: Square },
            { id: 'image', label: 'Image', icon: ImagePlus },
            { id: 'logo', label: 'Logo kit', icon: PenTool },
          ].map(({ id, label, icon: Icon }) => (
            <button key={id} className={`rail-tool ${activeTool === id ? 'active' : ''}`} onClick={() => { setActiveTool(id); flash(`${label} tool selected`) }} aria-label={label}>
              <Icon size={19} />
              <span>{label}</span>
            </button>
          ))}
          <div className="rail-spacer" />
          <button className="rail-tool" onClick={() => flash('Brand palette opened')} aria-label="Brand palette"><Palette size={19} /><span>Colors</span></button>
          <button className="rail-tool" aria-label="Help"><CircleHelp size={19} /><span>Support</span></button>
        </aside>

        <section className="canvas-area">
          <div className="canvas-toolbar">
            <div className="canvas-breadcrumb"><Shirt size={15} /> Apparel mockup <ChevronRight size={14} /> <span>{side} view</span></div>
            <div className="canvas-controls">
              <button className="control-button" onClick={() => setZoom(Math.max(40, zoom - 8))}><ZoomIn size={15} /></button>
              <span>{zoom}%</span>
              <button className="control-button" onClick={() => setZoom(Math.min(120, zoom + 8))}><Plus size={15} /></button>
              <div className="control-divider" />
              <button className="control-button" onClick={() => flash('Grid toggled')}><Grid3X3 size={15} /></button>
            </div>
          </div>

          <div className="stage-wrap">
            <div className="stage-grid" />
            <div className="canvas-card" style={{ transform: `scale(${zoom / 72})` }}>
              <div className="canvas-label">{side.toUpperCase()} / 01</div>
              <div className="hoodie" style={{ backgroundColor: garmentColor }}>
                <div className="hoodie-hood" />
                <div className="hoodie-sleeve left" />
                <div className="hoodie-sleeve right" />
                <div className="hoodie-pocket" />
                <div className="neck-line" />
                <div className="logo-placement">
                  {side === 'Front' ? <><div className="mountain-mark"><span /><span /><span /></div><div className="wordmark">NORTHSTAR</div></> : <div className="back-stamp">FIELD<br /><small>STUDY 01</small></div>}
                </div>
                <div className="size-tag">M</div>
              </div>
              <div className="canvas-footer"><span>2400 × 3000 px</span><span>PRINT SAFE</span></div>
            </div>
          </div>

          <div className="bottom-toolbar">
            <div className="history-chip"><RotateCcw size={14} /> Autosaved just now</div>
            <div className="view-switcher">
              <button className={side === 'Front' ? 'selected' : ''} onClick={() => setSide('Front')}>Front</button>
              <button className={side === 'Back' ? 'selected' : ''} onClick={() => setSide('Back')}>Back</button>
            </div>
            <button className="export-button" onClick={() => flash('Export prepared as PNG')}><ArrowDownToLine size={15} /> Export</button>
          </div>
        </section>

        <aside className="inspector">
          <div className="inspector-tabs"><button className="active">Design</button><button>Prototype</button></div>
          <div className="inspector-scroll">
            <section className="inspector-section layers-section">
              <div className="section-heading"><span>Layers</span><button className="mini-button" onClick={() => flash('New layer created')}><Plus size={14} /></button></div>
              <div className="layer-list">
                {layers.map((layer) => <div key={layer.id} className={`layer-row ${selectedLayer === layer.id ? 'selected' : ''}`} onClick={() => setSelectedLayer(layer.id)}>
                  <div className="layer-icon">{layer.id === 'mark' ? <Star size={14} /> : layer.id === 'wordmark' ? <Type size={14} /> : <Shirt size={14} />}</div>
                  <div className="layer-copy"><strong>{layer.name}</strong><span>{layer.type}</span></div>
                  <button className="layer-action" aria-label={`${layer.visible ? 'Hide' : 'Show'} ${layer.name}`} onClick={(event) => { event.stopPropagation(); toggleLayer(layer.id, 'visible') }}>{layer.visible ? <Eye size={14} /> : <EyeOff size={14} />}</button>
                  <button className="layer-action" aria-label={`${layer.locked ? 'Unlock' : 'Lock'} ${layer.name}`} onClick={(event) => { event.stopPropagation(); toggleLayer(layer.id, 'locked') }}>{layer.locked ? <Lock size={13} /> : <Unlock size={13} />}</button>
                </div>)}
              </div>
            </section>

            <section className="inspector-section">
              <div className="section-heading"><span>Garment</span><button className="collapse-button"><ChevronDown size={15} /></button></div>
              <div className="field-label">Color</div>
              <div className="swatches">{colors.map((color) => <button key={color.value} className={`swatch ${garmentColor === color.value ? 'active' : ''}`} style={{ backgroundColor: color.value }} aria-label={color.name} onClick={() => setGarmentColor(color.value)} />)}<button className="swatch custom-swatch" aria-label="Custom color"><Plus size={14} /></button></div>
              <div className="field-label row-label"><span>Opacity</span><span>100%</span></div>
              <input className="range" type="range" min="20" max="100" defaultValue="100" aria-label="Garment opacity" />
            </section>

            <section className="inspector-section">
              <div className="section-heading"><span>Placement</span><button className="collapse-button"><ChevronDown size={15} /></button></div>
              <div className="input-grid"><label>X<input value="50" readOnly /></label><label>Y<input value="42" readOnly /></label></div>
              <div className="field-label row-label"><span>Scale</span><span>1.0×</span></div>
              <input className="range" type="range" min="50" max="150" defaultValue="100" aria-label="Logo scale" />
              <button className="full-button" onClick={() => flash('Logo centered on garment')}><AlignCenter size={14} /> Center on garment</button>
            </section>

            <section className="inspector-section type-section">
              <div className="section-heading"><span>Brand type</span><button className="collapse-button"><ChevronDown size={15} /></button></div>
              <div className="font-row"><div><strong>Neue Montreal</strong><span>Medium / 16 px</span></div><ChevronDown size={15} /></div>
              <div className="type-preview">NORTHSTAR</div>
            </section>
          </div>
        </aside>
      </div>
      {toast && <div className="toast"><Sparkles size={14} /> {toast}</div>}
    </main>
  )
}
