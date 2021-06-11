// File: /home/ppibburr/git/q2/samples/q.rb




public class Foo {
  
  public int[] moof() {
    int[] a;
    ///home/ppibburr/git/q2/samples/q.rb: 5;
    a = {1, 2, 3};
    return a;
  }
  
  
  
  public virtual signal void foo(int a) {
  
    ///home/ppibburr/git/q2/samples/q.rb: 11;
    print("foo %d"+"\n",a);
  }
  
  
  
  public delegate void quux_cb(int a);
  
  
  public void quux(quux_cb cb) {
  
    ///home/ppibburr/git/q2/samples/q.rb: 19;
  
    foreach ( var q in moof() )  {
       cb(q); 
  
    }
  
    foo(33);
  }
}

public class Bar : Foo {
  // Fields set to infered type via @<var> assignment!
  public int one;
  private string _private;
  // END infered @<var>

  public int accessor { get; set; }
  public int reader { get; }
  public int writer { set; }
  public int prop1 {
   get;set; default = 5; 
  }
  
  private int _prop2;
  public int prop2 {
    
    get {
    ///home/ppibburr/git/q2/samples/q.rb: 34;
    return this._prop2;
    }
    
    
    set {
    ///home/ppibburr/git/q2/samples/q.rb: 35;
    this._prop2 = value;
    }
  }
  
  
  
  public  Bar(int a, string  b) {
    int[] p1;  string v;  int l;
    ///home/ppibburr/git/q2/samples/q.rb: 39;
    print(a.to_string()+"\n");
    this.one = 1;
    this._private = "no_see_me";
    print(b.to_string()+"\n");
    p1 = moof();
    print("p1 %d"+"\n",p1[1]);
    this.accessor = 11;
    accessor = 13;
    this._reader = 12;
    print("foo: %d"+"\n",this._accessor);
    this._accessor = 14;
    print("foo: %d"+"\n",this.accessor);
    print("foo: %d"+"\n",this._reader);
    print("bar: %d"+"\n",this.reader);
    print("each".to_string()+"\n");
  
    foreach ( var q in moof() )  {
       print(q.to_string()+"\n"); 
  
    }
  
    print("for".to_string()+"\n");
    var q_moof = moof();
  
    for (var i_n=0; i_n < q_moof.length; i_n++) {
  
      var i = q_moof[i_n];
      ///home/ppibburr/git/q2/samples/q.rb: 59;
      print(i.to_string()+"\n");
    }
  
    foo.connect( ( i) => {
       print("connect: %d"+"\n",i); 
    });
    print("cb".to_string()+"\n");
    quux( ( n) => {
       print(n.to_string()+"\n"); 
    });
    v = almost_last("ok", 69);
    l = last(new OtherB().other());
  }
  
  
  public string almost_last(string a, int  b) {
  
    ///home/ppibburr/git/q2/samples/q.rb: 75;
    print("al: %s -> %d"+"\n",a,b);
    return a;
  }
  
  
  public int last(int a) {
  
    ///home/ppibburr/git/q2/samples/q.rb: 80;
    return 69;
  }
  
  
  // # Program main entry;
  public static void main(string[] args) {
    Gtk.Window w;  OtherA<string,int> gtoa;  int other;
    ///home/ppibburr/git/q2/samples/q.rb: 86;
    new Bar(1, "two");
    print("%s: %d"+"\n","/home/ppibburr/git/q2/samples/q.rb",89);
    Gtk.init(ref args);
    w = new Gtk.Window(0);
    w.title = GLib.Environment.get_prgname();
    w.add(new Gtk.Label(((((("TTime = " + Q.tt.to_string()) + "\nThis label text set at:\n") + "/home/ppibburr/git/q2/samples/q.rb") + ": ") + 95.to_string())));
    w.show_all();
    print("%s"+"\n",new MappedFile("/home/ppibburr/git/q2/samples/q.rb", false).get_contents());
    w.delete_event.connect( () => {
       print("%s: %d => BYE!!"+"\n","/home/ppibburr/git/q2/samples/q.rb",99);
      Gtk.main_quit();
      return false; 
    });
    gtoa = new OtherA<string,int>("foo", 9);
    other = new OtherB().other();
    new Other();
    Gtk.main();
  }
}
