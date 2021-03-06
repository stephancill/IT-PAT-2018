unit Manager_Home_U;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, frmTemplate_U, StdCtrls, ExtCtrls, Grids, DBGrids, ComCtrls, TUser_U, TItem_U, TOrder_U, Logger_U, Data_Module_U, Utilities_U,
  New_User_U, DateUtils, TeEngine, TeeProcs, Chart, Series;

type
  TfrmManagerHome = class(TfrmTemplate, INewUserDelegate)
    lstEmployees: TListBox;
    btnNewEmployee: TButton;
    btnRemoveEmployee: TButton;
    Label1: TLabel;
    redDetails: TRichEdit;
    btnManageMenu: TButton;
    lstPopularItems: TListBox;
    lblDetails: TLabel;
    lblPopularItems: TLabel;
    cmbCategories: TComboBox;
    lstLast7Days: TListBox;
    lblLast7Days: TLabel;
    btnRestaurantName: TButton;
    chrtLast7Days: TChart;
    chrtMostPopular: TChart;
    procedure FormCreate(Sender: TObject);
    procedure lstEmployeesClick(Sender: TObject);
    procedure btnRemoveEmployeeClick(Sender: TObject);
    procedure btnNewEmployeeClick(Sender: TObject);
    procedure btnManageMenuClick(Sender: TObject);
    procedure cmbCategoriesChange(Sender: TObject);
    procedure btnRestaurantNameClick(Sender: TObject);
  private
    { Private declarations }
    procedure refreshEmployees;
    procedure showDetails(employee: TUser);
  public
    { Public declarations }
    procedure didCreateNewUser;
  end;

var
  frmManagerHome: TfrmManagerHome;

implementation

{$R *.dfm}

uses Menu_Management_U;

var
  arrEmployees: TUserArray;

procedure TfrmManagerHome.btnManageMenuClick(Sender: TObject);
var
  frmManageMenu: TfrmManageMenu;
begin
  inherited;
  frmManageMenu := TfrmManageMenu.Create(self);
  frmManageMenu.ShowModal;
end;

procedure TfrmManagerHome.btnNewEmployeeClick(Sender: TObject);
var
  frmNewUser: TfrmNewUser;
begin
  inherited;
  // Initialize new user creation process
  frmNewUser := TFrmNewUser.Create(self, self);
  frmNewUser.ShowModal;
  refreshEmployees;
end;

procedure TfrmManagerHome.btnRemoveEmployeeClick(Sender: TObject);
var
  selectedUser: TUser;
  optionselected: integer;
begin
  inherited;

  selectedUser := arrEmployees[lstEmployees.ItemIndex];
  optionselected := MessageDlg('Remove ' + selectedUser.GetFullName + '?',mtInformation, mbOKCancel, 0);

  // Confirm action
  if TMsgDlgBtn(optionSelected) <> mbOK then  // ??
  begin
    if Utilities.removeUser(selectedUser) then
      refreshEmployees;
  end;

end;

procedure TfrmManagerHome.btnRestaurantNameClick(Sender: TObject);
var
  oldName, newName: string;
begin
  inherited;
  // Handle possibility of name not set
  if not Utilities.getRestaurantName(oldName) then
    oldName := '[Restaurant Name]';

  // Get new name
  newName := InputBox('Restaurant Name', 'Choose a name for your restaurant', oldName);

  // Validate new name
  if ((newName <> oldName) and (length(newName) > 0)) then
  begin
    Utilities.setRestaurantName(newName);
  end else
  begin
    Utilities.setRestaurantName(oldName);
  end;
end;

procedure TfrmManagerHome.cmbCategoriesChange(Sender: TObject);
var
  titles: TStringArray;
  quantities: TIntegerArray;
  i: integer;
  series: TBarSeries;
begin
  inherited;
  // Filter popular items by category
  lstPopularItems.clear;
  if cmbCategories.ItemIndex <= 0 then
  begin
    if Utilities.getMostPopular(titles, quantities) then
    begin
      for I := 0 to length(titles)-1 do
      begin
        lstPopularItems.Items.Add(format('%-20s%-4s', [titles[i], inttostr(quantities[i])]))
      end;
    end;
  end else if Utilities.getMostPopularByCategory(titles, quantities, cmbCategories.Text) then
  begin
    for I := 0 to length(titles)-1 do
    begin
      lstPopularItems.Items.Add(format('%-20s%-4s', [titles[i], inttostr(quantities[i])]))
    end;
  end;

  series := TBarSeries.Create(self);
  chrtMostPopular.Legend.Hide;
  series.ParentChart := chrtMostPopular;

  chrtMostPopular.SeriesList[0].Clear;

  for i := 0 to length(titles)-1 do
  begin
    chrtMostPopular.Series[0].Add(quantities[i], titles[i], clWhite);
    chrtMostPopular.Series[0].Marks[i].Text.Add(inttostr(quantities[i]));
  end;
end;

procedure TfrmManagerHome.didCreateNewUser;
begin
  // Delegate method
  self.refreshEmployees;
end;

procedure TfrmManagerHome.FormCreate(Sender: TObject);
var
  titles, dates: TStringArray;
  quantities: TIntegerArray;
  revenues: TDoubleArray;
  I: Integer;
  categories: TStringArray;
  category: string;
  series: TBarSeries;
begin
  inherited;
  refreshEmployees;

  redDetails.Lines.Add('Select an employee to view details');

  if Utilities.getCategories(categories) then
  begin
    for category in categories do
    begin
      cmbCategories.Items.Add(category);
    end;
  end;

  // Initialize static analytics data
  if Utilities.getMostPopular(titles, quantities) then
  begin
    for I := 0 to length(titles)-1 do
    begin
      lstPopularItems.Items.Add(format('%-20s%-4s', [titles[i], inttostr(quantities[i])]))
    end;
    cmbCategories.ItemIndex := 0;
    cmbCategoriesChange(self);
  end;

  if Utilities.getDailyRevenue(revenues, dates, IncDay(now, -6), now) then
  begin
    series := TBarSeries.Create(self);
    chrtLast7Days.Legend.Hide;
    series.ParentChart := chrtLast7Days;

    for i := 0 to length(revenues)-1 do
    begin
      lstLast7Days.Items.Add(format('%-14s%8.2f', [dates[i], revenues[i]]));
      chrtLast7Days.Series[0].Add(revenues[i], dates[i], clWhite);
      chrtLast7Days.Series[0].Marks[i].Text.Add('');
    end;
  end;
end;

procedure TfrmManagerHome.lstEmployeesClick(Sender: TObject);
begin
  inherited;
  btnRemoveEmployee.Enabled := true;

  if lstEmployees.ItemIndex > -1 then
  begin
    showDetails(arrEmployees[lstEmployees.ItemIndex]);
  end;
end;

procedure TfrmManagerHome.refreshEmployees;
var
  user: TUser;
begin
  lstEmployees.clear;

  // Clear employees array
  arrEmployees := nil;
  finalize(arrEmployees);
  setLength(arrEmployees, 0);

  // Populate employees
  if Utilities.getEmployees(arrEmployees) then
  begin
    for user in arrEmployees do
    begin
      lstEmployees.Items.Add(Format('(%s) %s', [user.GetID, user.GetFullName]));
    end;
  end;
end;

procedure TfrmManagerHome.showDetails(employee: TUser);
var
  ordersTaken: integer;
  revenueGenerated: double;
begin
  // Name, register date
  redDetails.Clear;
  redDetails.Lines.Add(employee.GetFullName);
  redDetails.Lines.Add('');
  redDetails.Lines.Add('Register date ' + datetostr(employee.GetDateRegistered) + ' (' + inttostr(employee.GetDaysRegistered) + ' days)');

  redDetails.Lines.Add('');

  // Analytics - order count
  if Utilities.getOrderCount(ordersTaken, employee) then
  begin
    redDetails.Lines.Add(inttostr(ordersTaken) + ' orders processed.');
  end;

  // Analytics - total revenue
  if Utilities.getRevenueGenerated(revenueGenerated, employee) then
  begin
    redDetails.Lines.Add(Format('R%.2f revenue generated.', [revenueGenerated]));
  end;

end;

end.
