[CCode (cheader_file = "ruby/ruby.h")]
namespace RubyLoad {
  [CCode (cname = "ruby_init")]
  public void init();
  [CCode (cname = "ruby_init_loadpath")]
  public void init_loadpath();
  [CCode (cname = "rb_enc_find_index")]
  public void enc_find_index(string db);
  [CCode (cname = "rb_require")]
  public void _require(string db);  
  [CCode (cname = "rb_eval_string_protect")]
  public void* eval_string(string s, out int? state = null);
}
