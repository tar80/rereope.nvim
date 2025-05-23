---@meta

---@alias OptBeacon [string,integer,integer,integer]
---@alias Hint {winblend:integer,border:string[]}
---@alias Replace {mode?:string,regname?:string,regtype?:string,fallback:fun(line:string):string}
---@alias RereopeOptions {end_point:boolean,beacon:OptBeacon,hint:Hint,replace:Replace,motion:fun()}

---@class Reginfo
---@field regtype string 'v', 'V' and ''+count
---@field regcontents string[]
---@field isunnamed boolean Un-named register or not
---@field points_to string Register name currently pointed to

---@class Rereope
---@field new fun(self:self,regname:string,opts:RereopeOptions):Instance
---@field initial_related_options fun(self)
---@field restore_related_options fun(self)
---@field replace_regcontents fun(self)
---@field popup_hint fun(self)
---@field substitution fun(self,start_row:integer,start_col:integer,end_row:integer,end_col:integer):boolean?
---@field increase_reginfo fun(self)
---@field operator fun(motionwise:string)
---@field open fun(alterkey:string|nil, RereopeOptions)
---@field setup fun()

---@class Instance
---@field bufnr integer
---@field winid integer
---@field mode string
---@field selection 'old'|'inclusive'|'exclusive'
---@field clipboard string
---@field virtualedit 'block'|'insert'|'all'|'onemore'|'none'|'NONE'
---@field held_regname string First specified register name
---@field regname string Current specified register name
---@field reginfo Reginfo Current register information
---@field end_point boolean
---@field hint_options Hint
---@field beacon Beacon|false
---@field replace Replace
---@field motion fun()
---@field is_repeat boolean
---@field float [integer,integer]?
