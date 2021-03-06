unit Utilities_U;

interface

uses TUser_U, TItem_U, TOrder_U, ADODB, data_module_U, Logger_U, IdGlobal, IdHash, IdHashMessageDigest, SysUtils, Dialogs, StrUtils, DateUtils;

type
  TStringArray = array of string;
  TIntegerArray = array of integer;
  TDoubleArray = array of double;
  Utilities = class
    private
      const
        TAG: string = 'UTILITIES';
    public
      const
        LOGIN_CACHE_FILE: string = '.login';

      // Authentication
      class procedure persistLogin(email, password: string; hashed: boolean);
      class procedure depersistLogin;
      class function getPersistedLogin(var email, password: string): boolean;

      // User
      class function loginUser(userID, password: string; var user: TUser; hashed: boolean = false): boolean;
      class function newUser(var user: TUser; password: string; firstname, lastname: string; userType: TUserType; registerDate: TDateTime): boolean;
      class function changePassword(user: TUser; oldPassword, newPassword: string): boolean;
      class function updateUserInformation(user: TUser; var newUser: TUser): boolean;

      class function getEmployees(var employees: TUserArray): boolean;
      class function removeUser(user: TUser): boolean;

      // Item
      class function newItem(var item: TItem; title, category: string; price: double): boolean;
      class function getItems(var items: TItemArray): boolean;
      class function getOrderItems(var items: TItemArray; orderID: string): boolean;
      class function getCategories(var categories: TStringArray): boolean;

      // Order
      class function newOrder(var order: TOrder; employee: TUser; status: string; createDate: TDateTime; items: TItemArray): boolean;
      class function updateOrder(var order: TOrder; newStatus: String): boolean;
      class function getOrders(var orders: TOrderArray; employee: TUser): boolean;
      class function getIncompleteOrders(var orders: TOrderArray; employee: TUser): boolean;
      class function createReceipt(order: TOrder): boolean;

      // Analytics
      class function getMostPopularByCategory(var titles: TStringArray; var quantities: TIntegerArray; category: String): boolean;
      class function getMostPopular(var titles: TStringArray; var quantities: TIntegerArray): boolean;
      class function getOrderCount(var count: integer; user: TUser): boolean;
      class function getRevenueGenerated(var revenue: double; user: TUser): boolean;
      class function getDailyRevenue(var revenues: TDoubleArray; var dates: TStringArray; startDate: TDateTime; endDate: TDateTime): boolean;

      // Misc
      class function getMD5Hash(s: string): string;
      class function getLastID(var query: TADOQuery { or TQuery } ): Integer;
      class function getRestaurantName(var name: string): boolean;
      class function setRestaurantName(name: string): boolean;
  end;

implementation

{ Utilities }

class function Utilities.changePassword(user: TUser; oldPassword,
  newPassword: string): boolean;
var
  qry: TADOQuery;
begin
  { Change user's password }

  // Check if old password is correct
  qry := data_module.queryDatabase('SELECT * FROM Users WHERE [ID] = ' + user.getID + ' AND [Password] = ' + QuotedStr(getMD5Hash(oldPassword)), data_module.qry);

  if qry.eof then
  begin
    TLogger.log(TAG, Debug, 'Failed to change password of user with ID: ' + user.getID);
    result := false;
    Exit;
  end;

  // Update password
  result := data_module.modifyDatabase('UPDATE Users SET [Password] = ' + QuotedStr(getMD5Hash(newPassword)) +
  ' WHERE [ID] = ' + user.getID, data_module.qry);

  if result then
  begin
    TLogger.log(TAG, Debug, 'Successfully changed password of user with ID: ' + user.getID);
  end else
  begin
    TLogger.log(TAG, Debug, 'Failed to change password of user with ID: ' + user.getID);
  end;
end;

class function Utilities.createReceipt(order: TOrder): boolean;
var
  item: TItem;
  s, line, name: string;
  f: textfile;
  i: integer;
const
  separator: string = '----------------------------\n';
begin
  { Generate receipt and write it to a file }

  // Get name from configuration file
  if not getRestaurantName(name) then
    name := '[Restaurant Name]';

  s := Format('%s\nWaiter: %s\nDate: %s\n%s', [
    name,
    order.GetEmployee.GetFirstName,
    datetostr(order.GetCreateDate),
    separator
  ]);

  for item in order.GetItems do
  begin
    s := s + Format('%-20s%-3.2f\n', [item.GetTitle, item.GetPrice])
  end;

  s := Format(s + '%s item(s)\n%sSubtotal: R%.2f\nTax included @ 15p R%.2f\nOrder number: %s', [
    inttostr(length(order.GetItems)),
    separator,
    order.GetTotal,
    order.GetTotal * 1.15,
    order.GetID
  ]);

  // Write to textfile
  try
    AssignFile(f, 'Receipts\Order_' + order.GetID + '.txt');
  except
    on E: Exception do
    begin
      TLogger.logException(TAG, 'createReceipt', e);
      result := false;
      Exit;
    end;
  end;

  Rewrite(f);

  while pos('\n', s) > 0 do
  begin
    line := copy(s, 1, pos('\n', s)-1);
    s := copy(s, pos('\n', s)+2, length(s));
    writeln(f, line);
  end;
  writeln(f, s);

  closefile(f);

  result := true;
end;

class procedure Utilities.depersistLogin;
begin
  DeleteFile(LOGIN_CACHE_FILE);
end;

class function Utilities.getCategories(
  var categories: TStringArray): boolean;
var
  qry: TADOQuery;
begin
  { Get all categories present in menu }
  try
    qry := data_module.queryDatabase('SELECT DISTINCT Category FROM Items', data_module.qry);

    while not qry.Eof do
    begin
      setLength(categories, length(categories)+1);
      categories[length(categories)-1] := qry.FieldByName('Category').AsString;
      qry.Next;
    end;
    result := true;
  except
    result := false;
  end;
end;

class function Utilities.getDailyRevenue(var revenues: TDoubleArray;
  var dates: TStringArray; startDate, endDate: TDateTime): boolean;
var
  qry: TADOQuery;
  i: integer;
begin
  { Get daily revenue for a period of time }

  try
    for I := 0 to DaysBetween(startDate, endDate) do
    begin
      qry := data_module.queryDatabase(Format(
        'SELECT Sum(Price) AS Revenue '+
        'FROM Items INNER JOIN Order_Item ON Items.ID = Order_Item.ItemID ' +
        'WHERE (((Order_Item.OrderID) In (SELECT ID FROM Orders WHERE CreateDate = #%s#)))',
        [datetostr(IncDay(startDate, i))]
      ), data_module.qry);

      setLength(revenues, length(revenues)+1);
      setLength(dates, length(dates)+1);

      dates[length(dates)-1] := datetostr(IncDay(startDate, i));
      if not qry.Eof then
      begin
        revenues[length(revenues)-1] := qry.Fields[0].AsFloat;
      end else
      begin
        revenues[length(revenues)-1] := 0;
      end;
    end;

    result := true;
  except
    result := false;
  end;
end;

class function Utilities.getEmployees(var employees: TUserArray): boolean;
var
  qry: TADOQuery;
  user: TUser;
begin
  { Get all users with the employee type }

  try
    qry := data_module.queryDatabase('SELECT * FROM Users WHERE Type = 1 ORDER BY LastName', data_module.qry);

    while not qry.Eof do
    begin
      setLength(employees, length(employees)+1);
      user := TUser.Create(
        qry.FieldByName('ID').AsString,
        qry.FieldByName('FirstName').AsString,
        qry.FieldByName('LastName').AsString,
        TUserType(qry.FieldByName('Type').AsInteger),
        qry.FieldByName('RegisterDate').AsDateTime
      );
      employees[length(employees)-1] := user;
      qry.Next;
    end;
    result := true;
  except
    result := false;
  end;
end;

class function Utilities.getIncompleteOrders(var orders: TOrderArray;
  employee: TUser): boolean;
var
  allOrders: TOrderArray;
  order: TOrder;
begin
  { Get all incomplete orders by a specific employee }

  if getOrders(allOrders, employee) then
  begin
    for order in allOrders do
    begin
      if not order.IsComplete then
      begin
        setLength(orders, length(orders)+1);
        orders[length(orders)-1] := order;
      end;
    end;
    result := true;
  end else
  begin
    result := false;
  end;
end;

class function Utilities.getItems(var items: TItemArray): boolean;
var
  qry: TADOQuery;
  item: TItem;
begin
  { Get all menu items }

  try
    qry := data_module.queryDatabase('SELECT * FROM Items', data_module.qry);

    while not qry.Eof do
    begin
      setLength(items, length(items)+1);
      item := TItem.Create(
        qry.FieldByName('ID').AsString,
        qry.FieldByName('Title').AsString,
        qry.FieldByName('Category').AsString,
        qry.FieldByName('Price').AsFloat
      );
      items[length(items)-1] := item;
      qry.Next;
    end;
    result := true;
  except
    result := false;
  end;

end;

class function Utilities.getMD5Hash(s: string): string;
var
  hashMessageDigest5: TIdHashMessageDigest5;
begin
  { Generate hash for given string }

  hashMessageDigest5 := nil;
  try
    hashMessageDigest5 := TIdHashMessageDigest5.Create;
    result := IdGlobal.IndyLowerCase(hashMessageDigest5.HashStringAsHex(s));
  finally
    hashMessageDigest5.Free;
  end;
end;

class function Utilities.getMostPopular(var titles: TStringArray;
  var quantities: TIntegerArray): boolean;
var
  qry: TADOQuery;
begin
  { Get top 5 most popular items by sales }

  try
    qry := data_module.queryDatabase(
    'SELECT TOP 5 Items.Title, COUNT(Items.Title) AS [Quantity] FROM Items '+
    'INNER JOIN Order_Item ON Items.ID = Order_Item.ItemID '+
    'WHERE Order_Item.OrderID '+
    'IN (SELECT ID FROM Orders) '+
    'GROUP BY Items.Title '+
    'ORDER BY COUNT(Items.Title) DESC',
    data_module.qry);

    while not qry.Eof do
    begin
      setlength(titles, length(titles)+1);
      setlength(quantities, length(quantities)+1);
      titles[length(titles)-1] := qry.Fields[0].AsString;
      quantities[length(quantities)-1] := qry.Fields[1].AsInteger;
      qry.Next;
    end;

    result := true;
  except
    result := false;
  end;
end;

class function Utilities.getMostPopularByCategory(var titles: TStringArray; var quantities: TIntegerArray; category: string): boolean;
var
  qry: TADOQuery;
begin
  { Get top 5 most popular menu items by category }

  try
    qry := data_module.queryDatabase(
    'SELECT TOP 5 Items.Title, COUNT(Items.Title) AS [Quantity] FROM Items '+
    'INNER JOIN Order_Item ON Items.ID = Order_Item.ItemID '+
    'WHERE Order_Item.OrderID '+
    'IN (SELECT ID FROM Orders) AND Items.Category = ' + quotedStr(category) +
    'GROUP BY Items.Title '+
    'ORDER BY COUNT(Items.Title) DESC',
    data_module.qry);

    while not qry.Eof do
    begin
      setlength(titles, length(titles)+1);
      setlength(quantities, length(quantities)+1);
      titles[length(titles)-1] := qry.Fields[0].AsString;
      quantities[length(quantities)-1] := qry.Fields[1].AsInteger;
      qry.Next;
    end;

    result := true;
  except
    result := false;
  end;

end;

class function Utilities.getOrderCount(var count: integer;
  user: TUser): boolean;
var
  qry: TADOQuery;
begin
  { Count all the orders processed by a specific employee }

  try
    qry := data_module.queryDatabase('SELECT COUNT(ID) AS [Count] FROM Orders WHERE EmployeeID = ' + user.GetID,
      data_module.qry);
    count := qry.Fields[0].AsInteger;
  except
    result := false;
  end;
end;

class function Utilities.getOrderItems(var items: TItemArray;
  orderID: string): boolean;
var
  qry: TADOQuery;
  item: TItem;
begin
  { Get all the items contained in a specific order }

  try
    qry := data_module.queryDatabase(
      'SELECT Items.ID AS [ID], Title, Category, Price, Note FROM Items ' +
      'INNER JOIN Order_Item ON Items.ID = Order_Item.ItemID ' +
      'WHERE Order_Item.OrderID = ' + orderID,
    data_module.qryAux);

    while not qry.Eof do
    begin
      setLength(items, length(items)+1);
      item := TItem.Create(
        qry.FieldByName('ID').AsString,
        qry.FieldByName('Title').AsString,
        qry.FieldByName('Category').AsString,
        qry.FieldByName('Price').AsFloat
      );
      item.SetNote(qry.FieldByName('Note').AsString);
      items[length(items)-1] := item;
      qry.Next;
    end;
    result := true;
  except
    result := false;
  end;

end;

class function Utilities.getOrders(var orders: TOrderArray; employee: TUser): boolean;
var
  qry: TADOQuery;
  order: TOrder;
  items: TItemArray;
  id, status, completeDate: string;
  createDate: TDateTime;
begin
  { Get all the orders created by a specific user }

  try
    qry := data_module.queryDatabase(Format('SELECT * FROM Orders WHERE EmployeeID = %s', [employee.GetID]), data_module.qry);

    while not qry.Eof do
    begin
      setLength(orders, length(orders)+1);
      id := qry.FieldByName('ID').AsString;
      status := qry.FieldByName('Status').AsString;
      createDate := qry.FieldByName('CreateDate').AsDateTime;
      completeDate := qry.FieldByName('CompleteDate').AsString;

      items := nil;
      finalize(items);
      setLength(items, 0);
      getOrderItems(items, id);

      order := TOrder.Create(
         id,
         employee,
         status,
         createDate,
         items
      );

      if length(completeDate) > 0 then
      begin
        order.SetCompleteDate(strtodate(completeDate));
      end;

      orders[length(orders)-1] := order;
      qry.Next;
    end;
    result := true;
  except
    on E: Exception do
    begin
      TLogger.logException(TAG, 'getOrders', e);
      result := false;
      Exit;
    end;
  end;
end;

class function Utilities.getPersistedLogin(var email,
  password: string): boolean;
var
  f: TextFile;
begin
  { Store login cridentials for automatic login }

  AssignFile(f, LOGIN_CACHE_FILE);
  try
    Reset(f);
    readln(f, email);
    readln(f, password);
    Closefile(f);
  except
    on E: Exception do
    begin
      Showmessage('Something went wrong... Check logs for more information.');
      TLogger.logException(TAG, 'getPersistedLogin', e);
      result := false;
      Exit;
    end;
  end;

  result := true;
end;

class function Utilities.getRestaurantName(var name: string): boolean;
var
  f: TextFile;
begin
  { Extract restaurant name from persisted text file }

  try
    AssignFile(f, 'restaurant_name.txt');
    reset(f);
    assert(not eof(f));
  except
    on E: Exception do
    begin
      TLogger.logException(TAG, 'getRestaurantName', e);
      result := false;
      Exit;
    end;
  end;

  readln(f, name);
  closefile(f);

  result := true;
end;

class function Utilities.getRevenueGenerated(var revenue: double;
  user: TUser): boolean;
var
  qry: TADOQuery;
begin
  { Calculate the total revenue generated by a specified user }

  try
    qry := data_module.queryDatabase(
    'SELECT SUM(Price) AS [Total] FROM Items ' +
    'INNER JOIN Order_Item ON Items.ID = Order_Item.ItemID '+
    'WHERE Order_Item.OrderID IN (SELECT ID FROM Orders WHERE '+
    'EmployeeID = ' + user.GetID + ')',
      data_module.qry);
    revenue := qry.Fields[0].AsFloat;
  except
    result := false;
  end;
end;

class function Utilities.loginUser(userID, password: string; var user: TUser;
  hashed: boolean): boolean;
var
  qry: TADOQuery;
  id, firstname, lastname: string;
  userType: Integer;
  registerDate: TDateTime;
begin
  {
    Authenticate a user to use the system using their ID and password
    1. Check if user exists
    2. Retrieve user record
    3. Create and return TUser object
  }
  if not hashed then
    password := getMD5Hash(password);

  qry := data_module.queryDatabase('SELECT * FROM Users WHERE ID = ' + userID
      + ' AND password = ' + quotedStr(password), data_module.qry);

  // 1. Check if user exists
  if not qry.Eof then
  begin
    // 2. Retrieve user record
    id := qry.FieldByName('ID').AsString;
    userType := qry.FieldByName('Type').AsInteger;
    firstname := qry.FieldByName('FirstName').AsString;
    lastname := qry.FieldByName('LastName').AsString;
    registerDate := qry.FieldByName('RegisterDate').AsDateTime;

    // 3. Create and return TUser object
    user := TUser.Create(id, firstname, lastname, TUserType(userType), registerDate);

    TLogger.log(TAG, Debug,
      'Successfully logged in user with ID: ' + id);

    result := true;
    Exit;
  end
  else
    result := false;

  TLogger.log(TAG, Error, 'Failed login attempt with ID: ' + userID);

end;

class function Utilities.newItem(var item: TItem; title, category: string;
  price: double): boolean;
begin
  { Create a new menu item in the database }

  result := data_module.modifyDatabase(Format('INSERT INTO Items (Title, Category, Price) VALUES (%s, %s, %s)', [
    quotedstr(title),
    quotedStr(category),
    floattostr(price)
  ]), data_module.qry);

  item := TItem.Create(inttostr(getLastID(data_module.qry)), title, category, price);

  if result then
  begin
    TLogger.log(TAG, Debug, 'Successfully added new item with ID: ' + item.GetID);
  end else
  begin
    TLogger.log(TAG, Debug, 'Failed to add item with name: ' + item.GetTitle);
  end;
end;

class function Utilities.newOrder(var order: TOrder; employee: TUser;
  status: string; createDate: TDateTime; items: TItemArray): boolean;
var
  item: TItem;
  note: string;
begin
  { Create a new order in the database }

  result := data_module.modifyDatabase(Format('INSERT INTO Orders (EmployeeID, Status, CreateDate) VALUES (%s, %s, #%s#)', [
    employee.GetID,
    quotedStr(status),
    datetostr(createDate)//FormatDateTime('c', createDate)  // IMPROVEMENT: Accomodate time
  ]), data_module.qry);

  order := TOrder.Create(inttostr(getLastID(data_module.qry)), employee, status, createDate, items);

  // Insert each item into the Order_Item junction table
  for item in items do
  begin
    note := item.GetNote;
    result := result and data_module.modifyDatabase(Format('INSERT INTO Order_Item (OrderID, ItemID, [Note]) VALUES (%s, %s, %s)', [
    order.GetID,
    item.GetID,
    quotedStr(note)
  ]), data_module.qry);
  end;

  if result then
  begin
    TLogger.log(TAG, Debug, 'Successfully created order with ID: ' + order.GetID);
  end else
  begin
    TLogger.log(TAG, Debug, 'Failed to create order with ID: ' + order.GetID);
  end;
end;

class function Utilities.newUser(var user: TUser; password: string;
  firstname, lastname: string; userType: TUserType; registerDate: TDateTime): boolean;
begin
  { Create a new user }

  result := data_module.modifyDatabase(Format('INSERT INTO Users (FirstName, LastName, [Type], [Password], RegisterDate) VALUES (%s, %s, %s, %s, #%s#)', [
    quotedstr(firstName),
    quotedStr(lastName),
    inttostr(ord(userType)),
    quotedStr(getmd5hash(password)),
    datetostr(registerdate)
  ]), data_module.qry);

  if result then
  begin
    user := TUser.Create(inttostr(getLastID(data_module.qry)), firstname, lastname, userType, registerdate);
  end;

end;

class procedure Utilities.persistLogin(email, password: string; hashed: boolean);
var
  f: TextFile;
begin
  { Persist a login credentials for automatic login }

  TLogger.log(TAG, Debug, 'Persisting login for user with email: ' + email);

  //
  if not hashed then
    password := getMD5Hash(password);

  AssignFile(f, LOGIN_CACHE_FILE);
  try
    Rewrite(f);
    writeLn(f, email);
    writeLn(f, password);
    CloseFile(f);
  except
    on E: Exception do
    begin
      Showmessage('Something went wrong... Check logs for more information.');
      TLogger.logException(TAG, 'persistLogin', e);
      Exit;
    end;
  end;
end;

class function Utilities.removeUser(user: TUser): boolean;
begin
  { Delete a user from the database }

  result := data_module.modifyDatabase(Format('DELETE FROM Users WHERE ID = %s', [user.GetID]), data_module.qry);

  if result then
  begin
    TLogger.log(TAG, Debug, 'Successfully removed user with ID: ' + user.GetID);
  end else
  begin
    TLogger.log(TAG, Debug, 'Failed to remove user with ID: ' + user.GetID);
  end;
end;

class function Utilities.setRestaurantName(name: string): boolean;
var
  f: TextFile;
begin
  { Persist restaurant name in text file }

  AssignFile(f, 'restaurant_name.txt');
  rewrite(f);
  writeln(f, name);
  closefile(f);

  result := true;
end;

class function Utilities.updateOrder(var order: TOrder; newStatus: String): boolean;
begin
  { Update the status of an order }

  result := data_module.modifyDatabase(Format('UPDATE Orders SET Status = %s, CompleteDate = %s WHERE ID = %s', [
    quotedStr(newStatus),
    ifThen(lowercase(newStatus) = 'complete', '#'+datetostr(now)+'#', 'NULL'),
    order.GetID
  ]), data_module.qry);
  if result then
    order.SetStatus(newstatus);

  // Handle complete order
  if lowercase(newStatus) = 'complete' then
  begin
    order.SetCompleteDate(now);
  end;
  

  if result then
  begin
    TLogger.log(TAG, Debug, 'Successfully changed information of order with ID: ' + order.GetID);
  end else
  begin
    TLogger.log(TAG, Debug, 'Failed to change information of order with ID: ' + order.GetID);
  end;
end;

class function Utilities.updateUserInformation(user: TUser;
  var newUser: TUser): boolean;
begin
  { Update user information }

  newUser := TUser.Create(user.GetID, user.GetFirstName, user.GetLastName, user.GetType, user.GetDateRegistered);
  // Update information
  result := data_module.modifyDatabase(Format('UPDATE Users SET FirstName = %s, LastName = %s, [Type] = %s WHERE [ID] = %s', [
    quotedStr(newUser.GetFirstName),
    quotedStr(newUser.GetLastName),
    inttostr(integer(newUser.GetType)),
    newUser.GetID
  ]), data_module.qry);

  if result then
  begin
    TLogger.log(TAG, Debug, 'Successfully changed information of user with ID: ' + user.getID);
  end else
  begin
    TLogger.log(TAG, Debug, 'Failed to change information of user with ID: ' + user.getID);
  end;
end;

// http://www.swissdelphicenter.com/en/showcode.php?id=1749
class function Utilities.getLastID(var query: TADOQuery): Integer;
begin
  { Get the ID of the last inserted record in the database }
  result := -1;
  try
    query.sql.clear;
    query.sql.Add('SELECT @@IDENTITY');
    query.Active := true;
    query.First;
    result := query.Fields.Fields[0].AsInteger;
  finally
    query.Active := false;
    query.sql.clear;
  end;
end;

end.
