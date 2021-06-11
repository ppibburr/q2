// File: /home/ppibburr/git/q2/samples/a.rb



public class OtherA<G, T> {
  // Fields set to infered type via @<var> assignment!
  public T t;
  // END infered @<var>

  
  
  public  OtherA(G g, T  _t) {
  
    ///home/ppibburr/git/q2/samples/a.rb: 5;
    this.t = _t;
    print("file a: %s"+"\n",g);
  }
  
  
  public T rt() {
  
    ///home/ppibburr/git/q2/samples/a.rb: 10;
    return this.t;
  }
}
