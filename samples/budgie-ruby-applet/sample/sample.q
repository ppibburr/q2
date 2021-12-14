require q: './budgie_ruby.q'

defn [TypeModule]
def peas_register_types(_module)
  Q::Applet.register(_module, typeof(BudgieRuby::Applet))
end

