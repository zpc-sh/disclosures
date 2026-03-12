//
//  VimViewController.swift
//  Kyozo
//
//  Created by Loc Nguyen on 8/16/25.
//



class VimViewController: NSViewController {
    weak var delegate: VimDelegate?
    var document: Document!
    var claudeAvatar: ClaudeAvatarEngine!
    
    private var metalView: MTKView!
    private var vimCore: VimCore!
    private var renderPipeline: MTLRenderPipelineState!
    
    override func loadView() {
        // Create Metal view for vim rendering
        metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = self
        metalView.preferredFramesPerSecond = 120
        
        self.view = metalView
        
        // Initialize actual Vim
        vimCore = VimCore()
        vimCore.start()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup vim with full keybindings
        setupVimBindings()
        
        // Load document into vim buffer
        vimCore.loadBuffer(document.content)
        
        // Start Claude walking around
        claudeAvatar.startWalking(in: view.bounds)
    }
    
    private func setupVimBindings() {
        // ALL the vim commands
        let vimCommands = """
        set nocompatible
        set number relativenumber
        set hlsearch incsearch
        set expandtab tabstop=2 shiftwidth=2
        set autoindent smartindent
        
        " Custom Kyozo commands
        command! KyozoExecute :call KyozoExecuteBlock()
        command! KyozoEnhance :call KyozoEnhanceWithClaude()
        command! KyozoGPU :call KyozoToggleGPU()
        
        " Keybindings
        nnoremap <leader>r :KyozoExecute<CR>
        nnoremap <leader>e :KyozoEnhance<CR>
        nnoremap <leader>g :KyozoGPU<CR>
        
        " Claude avatar interactions
        nnoremap <leader>c :call SummonClaude()<CR>
        nnoremap <leader>? :call AskClaude()<CR>
        
        " Enable vim-surround behavior
        vnoremap s( c(<C-r>")<Esc>
        vnoremap s[ c[<C-r>"]<Esc>
        vnoremap s{ c{<C-r>"}<Esc>
        vnoremap s" c"<C-r>""<Esc>
        vnoremap s' c'<C-r>"'<Esc>
        vnoremap s` c`<C-r>"`<Esc>
        """
        
        vimCore.execute(vimCommands)
    }
    
    override func keyDown(with event: NSEvent) {
        // Send keystrokes to vim
        let key = event.charactersIgnoringModifiers ?? ""
        let modifiers = event.modifierFlags
        
        if modifiers.contains(.control) {
            vimCore.sendKey("^" + key)
        } else if modifiers.contains(.command) {
            vimCore.sendKey("D-" + key)
        } else {
            vimCore.sendKey(key)
        }
        
        // Update Claude's reaction
        claudeAvatar.reactToVimCommand(key)
        
        // Redraw
        metalView.setNeedsDisplay()
    }
}

