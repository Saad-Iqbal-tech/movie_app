import 'package:flutter/material.dart';


class First extends StatelessWidget{
  
  First({super.key});
  
  @override
  Widget build(BuildContext context){
    

    return Scaffold(
      
      appBar: AppBar(
        title: Text("page 1"),
      ),

      drawer:Drawer(
        backgroundColor: Colors.greenAccent,
        child: Column(

          children: [
            DrawerHeader(child: Icon(Icons.person,size: 48,)),

            ListTile(
              title: Text("Home"),
              leading: Icon(Icons.home),
              onTap: (){
                Navigator.pop(context);
                Navigator.pushNamed(context,'/second');
              },



            ),

      ListTile(
        title: Text("Home"),
        leading: Icon(Icons.home),
        onTap: (){
          Navigator.pop(context);
          Navigator.pushNamed(context,'/second');
        },),


            ListTile(
              title: Text("Home"),
              leading: Icon(Icons.home),
              onTap: (){
                Navigator.pop(context);
                Navigator.pushNamed(context,'/second');
              },),

            ListTile(
              title: Text("Home"),
              leading: Icon(Icons.home),
              onTap: (){
                Navigator.pop(context);
                Navigator.pushNamed(context,'/second');
              },),
          ],
        ),
      ),

      body:Center(
        child: ElevatedButton(
          child: Text("Go to Second Page"),
          onPressed: () => {
            Navigator.pushNamed(context,'/second'),
          }
        ),
      )
      
    );
  }
}