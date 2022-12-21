
/*Linked Services Local*/

EXEC master.dbo.sp_addlinkedserver
    @server = N'salesAW', 
    @srvproduct=N'', 
    @provider=N'SQLNCLI', 
    @provstr=N'DRIVER={SQL Server};Server=; Initial Catalog=AdventureWorks2019;uid=;pwd=;'

EXEC master.dbo.sp_addlinkedserver
    @server = N'productionAW', 
    @srvproduct=N'', 
    @provider=N'SQLNCLI', 
    @provstr=N'DRIVER={SQL Server};Server=; Initial Catalog=AdventureWorks2019;uid=;pwd=;'

EXEC master.dbo.sp_addlinkedserver
    @server = N'otrosAW', 
    @srvproduct=N'', 
    @provider=N'SQLNCLI', 
    @provstr=N'DRIVER={SQL Server};Server=; Initial Catalog=AdventureWorks2019;uid=;pwd=;'

/*a. Determinar el total de las ventas de los productos de la categoría que se provea 
como argumento de entrada en la consulta, para cada uno de los territorios 
registrados en la base de datos o para cada una de las regiones (atributo group
de SalesTerritory) según se especifique como argumento de entrada.*/

create or alter procedure CA @idCategoria int as
select soh.TerritoryID, sum(t.LineTotal) as Total_Ventas
from salesAW.AdventureWorks2019.Sales.SalesOrderHeader soh
inner join
(select salesorderid, productid, orderqty, linetotal
from salesAW.AdventureWorks2019.Sales.SalesOrderDetail sod
where ProductID in (
	select ProductID
	from productionAW.AdventureWorks2019.Production.Product
	where ProductSubcategoryID in (
		select ProductSubcategoryID
		from productionAW.AdventureWorks2019.Production.ProductSubcategory
		where ProductCategoryID in(
			select ProductCategoryID
			from productionAW.AdventureWorks2019.Production.ProductCategory	
			where ProductCategoryID = @idCategoria
		)
	)
)) as T
on soh.SalesOrderID = t.SalesOrderID
group by soh.TerritoryID
order by soh.TerritoryID


exec CA 1


--Duda--
/*b. Determinar el producto más solicitado para la región (atributo group de 
salesterritory) que se especifique como argumento de entrada y en que 
territorio de la región tiene mayor demanda.*/

	create or alter procedure CB as
		select top 1 D.[Name] as Producto, count(*) as Solicitudes, B.[Group] as Region from
		(select * from salesAW.AdventureWorks2019.Sales.SalesOrderHeader) as A
		inner join
		(select *  from salesAW.AdventureWorks2019.Sales.SalesTerritory where TerritoryID between '1' and '6') as B
		on A.TerritoryID = B.TerritoryID
		inner join
		(select * from salesAW.AdventureWorks2019.Sales.SalesOrderDetail) as C
		on A.SalesOrderID = C.SalesOrderID
		inner join
		(select * from productionAW.AdventureWorks2019.Production.Product) as D
		on C.ProductID = D.ProductID
	group by B.[Group], D.[Name]
	order by Solicitudes desc

exec CB

/*c. Actualizar el stock disponible en un 5% de los productos de la categoría que se 
provea como argumento de entrada, en una localidad que también se provea 
como argumento de entrada en la instrucción de actualización.*/

create or alter procedure CC @idCategoria int, @idLocation int as
begin
	if not exists(select B.ProductID, C.[Name], A.[Name] as Localidad, B.Quantity as Stock from (
	(select * from productionAW.AdventureWorks2019.Production.[Location] where LocationID = @idLocation) as A
	inner join
	(select * from productionAW.AdventureWorks2019.Production.ProductInventory) as B
	on B.LocationID = A.LocationID
	inner join
	(select * from productionAW.AdventureWorks2019.Production.Product) as C
	on B.ProductID = C.ProductID
	inner join
	(select * from productionAW.AdventureWorks2019.Production.ProductSubcategory where ProductCategoryID = @idCategoria) as D
	on D.ProductSubcategoryID = C.ProductSubcategoryID))
		begin
			print 'Error: No se encontró la categoria ingresada en esa localidad'
		end
	else
	begin
		update productionAW.AdventureWorks2019.Production.ProductInventory
		set Quantity = floor(Quantity*1.05)
		where LocationID = @idLocation 
		and ProductID in (	select ProductID
				from productionAW.AdventureWorks2019.Production.Product
				where ProductSubcategoryID in (select ProductSubcategoryID
												from productionAW.AdventureWorks2019.Production.ProductSubcategory
												where ProductCategoryID=@idCategoria))
			select * from productionAW.AdventureWorks2019.Production.ProductInventory 
			where LocationID = @idLocation 
			and ProductID in (	select ProductID
								from productionAW.AdventureWorks2019.Production.Product
								where ProductSubcategoryID in (select ProductSubcategoryID
																from productionAW.AdventureWorks2019.Production.ProductSubcategory
																where ProductCategoryID=@idCategoria))
	end
end

exec CC 2,60

--Duda--
/*d. Determinar si hay clientes de un territorio que se especifique como argumento 
de entrada, que realizan ordenes en territorios diferentes al que se encuentran. */

create or alter procedure CD as
begin
	if not exists(
	select A.CustomerID as Cliente, A.TerritoryID as Direccion_Cliente, C.TerritoryID as Direccion_Pedido from (
	(select * from salesAW.AdventureWorks2019.Sales.Customer) as A
	inner join
	(select * from salesAW.AdventureWorks2019.Sales.SalesTerritory) as B
	on A.TerritoryID = B.TerritoryID
	inner join
	(select * from salesAW.AdventureWorks2019.Sales.SalesOrderHeader) as C
	on B.TerritoryID = C.TerritoryID)
	where A.TerritoryID != C.TerritoryID)
		print 'No existen clientes que hayan realizado pedidos en territorios distintos'
	else
		print 'Si existen'
		select * from salesAW.AdventureWorks2019.Sales.Customer
end


exec CD


/*e. Actualizar la cantidad de productos de una orden que se provea como 
argumento en la instrucción de actualización.*/

create or alter procedure CE @idProducto int, @idOrden int , @cantidad int as
begin 
	if not exists (select * from salesAW.AdventureWorks2019.Sales.SalesOrderDetail where ProductId = @idProducto)
		print 'Error: Este producto no existe'
	else 
		begin
			if not exists (select * from salesAW.AdventureWorks2019.Sales.SalesOrderDetail where SalesOrderID = @idOrden and ProductID = @idProducto)
				print 'Error: Verifica el numero de orden'
			else
				begin
					update salesAW.AdventureWorks2019.Sales.SalesOrderDetail
					set OrderQty = @cantidad
					where SalesOrderID = @idOrden and ProductID = @idProducto
					select * from salesAw.AdventureWorks2019.Sales.SalesOrderDetail where SalesOrderID = @idOrden and ProductID = @idProducto
				end
		end
end

exec CE 776, 43659, 3

/*f. Actualizar el método de envío de una orden que se reciba como argumento en 
la instrucción de actualización.*/

create or alter procedure CF @metodoEnvio int, @idOrden int as
begin
	if not exists(select * from salesAW.AdventureWorks2019.Sales.SalesOrderHeader where SalesOrderID = @idOrden)
		print 'Error: No existe dicha orden '
	else
	begin
		update salesAW.AdventureWorks2019.Sales.SalesOrderHeader
		set ShipMethodID = @metodoEnvio
		where SalesOrderID = @idOrden
		print 'El metodo de envio se actualizo correctamente'
		select ShipMethodID from salesAW.AdventureWorks2019.Sales.SalesOrderHeader where SalesOrderID = @idOrden
	end
end

exec CF 5, 43659


/*g. Actualizar el correo electrónico de una cliente que se reciba como argumento 
en la instrucción de actualización.*/

create or alter procedure CG @nombre nvarchar(100), @apellido nvarchar(100), @correo nvarchar(100) as
begin
	if not exists ( select * from AdventureWorks2019.Person.EmailAddress 
			where BusinessEntityID in(
				select BusinessEntityID 
				from AdventureWorks2019.Person.Person as A
				where A.FirstName=@nombre and A.LastName=@apellido))
		print('Error: No se encontro a la persona ingresada')
	else
	begin
		update AdventureWorks2019.Person.EmailAddress set EmailAddress = @correo
			where BusinessEntityID in(
					select BusinessEntityID from AdventureWorks2019.Person.Person
					where FirstName=@nombre and LastName=@apellido)
	
	select * from AdventureWorks2019.Person.EmailAddress where BusinessEntityID in(
					select BusinessEntityID from AdventureWorks2019.Person.Person
					where FirstName=@nombre and LastName=@apellido)
	end
end

exec CG 'Terri', 'Duffy', 'Mucho@prueba.com'


/*h. Determinar el empleado que atendió más ordenes por territorio/región.*/

CREATE PROCEDURE CH AS
BEGIN
	SELECT TerritoryID,SalesPersonID, P.FirstName, P.LastName, Total_Pedidos FROM
	(SELECT TOP 1 * FROM (
	SELECT TerritoryID, SalesPersonID, count(*) as Total_Pedidos
	FROM Sales.SalesOrderHeader WHERE SalesPersonID IS NOT NULL AND TerritoryID = 1 GROUP BY SalesPersonId, TerritoryID ) 
	AS pedidos ORDER BY TerritoryID, Total_Pedidos DESC) AS territory1  INNER JOIN Person.Person as P ON territory1.SalesPersonID = P.BusinessEntityID

	UNION 

	SELECT TerritoryID,SalesPersonID, P.FirstName, P.LastName, Total_Pedidos FROM
	(SELECT TOP 1 * FROM (
	SELECT TerritoryID, SalesPersonID, count(*) as Total_Pedidos
	FROM Sales.SalesOrderHeader WHERE SalesPersonID IS NOT NULL AND TerritoryID = 2 GROUP BY SalesPersonId, TerritoryID ) 
	AS pedidos ORDER BY TerritoryID, Total_Pedidos DESC) AS territory2  INNER JOIN Person.Person as P ON territory2.SalesPersonID = P.BusinessEntityID

	UNION

	SELECT TerritoryID,SalesPersonID, P.FirstName, P.LastName, Total_Pedidos FROM
	(SELECT TOP 1 * FROM (
	SELECT TerritoryID, SalesPersonID, count(*) as Total_Pedidos
	FROM Sales.SalesOrderHeader WHERE SalesPersonID IS NOT NULL AND TerritoryID = 3 GROUP BY SalesPersonId, TerritoryID ) 
	AS pedidos ORDER BY TerritoryID, Total_Pedidos DESC) AS territory3  INNER JOIN Person.Person as P ON territory3.SalesPersonID = P.BusinessEntityID

	UNION 

	SELECT TerritoryID,SalesPersonID, P.FirstName, P.LastName, Total_Pedidos FROM
	(SELECT TOP 1 * FROM (
	SELECT TerritoryID, SalesPersonID, count(*) as Total_Pedidos
	FROM Sales.SalesOrderHeader WHERE SalesPersonID IS NOT NULL AND TerritoryID = 4 GROUP BY SalesPersonId, TerritoryID ) 
	AS pedidos ORDER BY TerritoryID, Total_Pedidos DESC) AS territory4  INNER JOIN Person.Person as P ON territory4.SalesPersonID = P.BusinessEntityID

	UNION

	SELECT TerritoryID,SalesPersonID, P.FirstName, P.LastName, Total_Pedidos FROM
	(SELECT TOP 1 * FROM (
	SELECT TerritoryID, SalesPersonID, count(*) as Total_Pedidos
	FROM Sales.SalesOrderHeader WHERE SalesPersonID IS NOT NULL AND TerritoryID = 5 GROUP BY SalesPersonId, TerritoryID ) 
	AS pedidos ORDER BY TerritoryID, Total_Pedidos DESC) AS territory5  INNER JOIN Person.Person as P ON territory5.SalesPersonID = P.BusinessEntityID

	UNION 

	SELECT TerritoryID,SalesPersonID, P.FirstName, P.LastName, Total_Pedidos FROM
	(SELECT TOP 1 * FROM (
	SELECT TerritoryID, SalesPersonID, count(*) as Total_Pedidos
	FROM Sales.SalesOrderHeader WHERE SalesPersonID IS NOT NULL AND TerritoryID = 6 GROUP BY SalesPersonId, TerritoryID ) 
	AS pedidos ORDER BY TerritoryID, Total_Pedidos DESC) AS territory6  INNER JOIN Person.Person as P ON territory6.SalesPersonID = P.BusinessEntityID

	UNION

	SELECT TerritoryID,SalesPersonID, P.FirstName, P.LastName, Total_Pedidos FROM
	(SELECT TOP 1 * FROM (
	SELECT TerritoryID, SalesPersonID, count(*) as Total_Pedidos
	FROM Sales.SalesOrderHeader WHERE SalesPersonID IS NOT NULL AND TerritoryID = 7 GROUP BY SalesPersonId, TerritoryID ) 
	AS pedidos ORDER BY TerritoryID, Total_Pedidos DESC) AS territory7  INNER JOIN Person.Person as P ON territory7.SalesPersonID = P.BusinessEntityID

	UNION 

	SELECT TerritoryID,SalesPersonID, P.FirstName, P.LastName, Total_Pedidos FROM
	(SELECT TOP 1 * FROM (
	SELECT TerritoryID, SalesPersonID, count(*) as Total_Pedidos
	FROM Sales.SalesOrderHeader WHERE SalesPersonID IS NOT NULL AND TerritoryID = 8 GROUP BY SalesPersonId, TerritoryID ) 
	AS pedidos ORDER BY TerritoryID, Total_Pedidos DESC) AS territory8  INNER JOIN Person.Person as P ON territory8.SalesPersonID = P.BusinessEntityID

	UNION

	SELECT TerritoryID,SalesPersonID, P.FirstName, P.LastName, Total_Pedidos FROM
	(SELECT TOP 1 * FROM (
	SELECT TerritoryID, SalesPersonID, count(*) as Total_Pedidos
	FROM Sales.SalesOrderHeader WHERE SalesPersonID IS NOT NULL AND TerritoryID = 9 GROUP BY SalesPersonId, TerritoryID ) 
	AS pedidos ORDER BY TerritoryID, Total_Pedidos DESC) AS territory9  INNER JOIN Person.Person as P ON territory9.SalesPersonID = P.BusinessEntityID

	UNION 

	SELECT TerritoryID,SalesPersonID, P.FirstName, P.LastName, Total_Pedidos FROM
	(SELECT TOP 1 * FROM (
	SELECT TerritoryID, SalesPersonID, count(*) as Total_Pedidos
	FROM Sales.SalesOrderHeader WHERE SalesPersonID IS NOT NULL AND TerritoryID = 10 GROUP BY SalesPersonId, TerritoryID ) 
	AS pedidos ORDER BY TerritoryID, Total_Pedidos DESC) AS territory10  INNER JOIN Person.Person as P ON territory10.SalesPersonID = P.BusinessEntityID

END

EXECUTE CH

/*i. Determinar para un rango de fechas establecidas como argumento de entrada,
cual es el total de las ventas en cada una de las regiones.*/

create or alter procedure CI @fechaEntrada Date, @fechaSalida Date as
begin
	if not exists(select TerritoryID from salesAW.AdventureWorks2019.Sales.SalesOrderHeader where OrderDate between @fechaEntrada and @fechaSalida)
		print 'Error: No hay ventas en esas fechas'
	else
	begin
		SELECT TerritoryID, SUM(TotalDue) AS Total_Ventas 
		FROM salesAW.AdventureWorks2019.Sales.SalesOrderHeader 
		WHERE OrderDate BETWEEN @fechaEntrada AND @fechaSalida GROUP BY TerritoryID ORDER BY TerritoryID
	end
end

exec CI '2011-05-31', '2011-06-30'

/*j. Determinar los 5 productos menos vendidos en un rango de fecha establecido 
como argumento de entrada.*/


create or alter procedure CJ @fechaEntrada Date, @fechaSalida Date as
begin
	if not exists(SELECT TerritoryID FROM salesAW.AdventureWorks2019.Sales.SalesOrderHeader WHERE OrderDate BETWEEN @fechaEntrada AND @fechaSalida )
		print 'Error: No hay ventas en esas fechas'
	else
	begin
		SELECT top 5 ProductID, SUM(OrderQty) AS Cantidad_Productos
		FROM salesAW.AdventureWorks2019.Sales.SalesOrderDetail 
		WHERE EXISTS (
				SELECT TerritoryID, SalesOrderID
				FROM salesAW.AdventureWorks2019.Sales.SalesOrderHeader
				WHERE OrderDate BETWEEN @fechaEntrada AND @fechaSalida 
		)
		GROUP BY ProductID ORDER BY Cantidad_Productos
	end
end

exec CJ '2011-05-31', '2011-05-31'