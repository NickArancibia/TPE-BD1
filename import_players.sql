create table futbolista(
        nombre varchar(50) not null,
        posicion varchar(50) not null,
        edad int not null,
        altura float,
        pie varchar(20),
        fichado date,
        equipo_anterior varchar(50),
        valor_mercado int,
        equipo varchar(50),
        primary key(nombre)
)

create table dorsal(
        jugador varchar(50) not null,
        dorsal int not null,
        foreign key(jugador) references futbolista(nombre),
        primary key(jugador)
)

/* a ejecutar dentro de la terminal psql */

\set path_to_csv 'C:/Users/Dell/jugadores-2022.csv'  /* opcionalmente se puede usar una variable para el path */

\COPY futbolista(nombre, posicion, edad, altura, pie, fichado, equipo_anterior, valor_mercado, equipo) FROM :path_to_csv WITH (FORMAT csv, DELIMITER ';', NULL '', HEADER true, ENCODING 'UTF8');
