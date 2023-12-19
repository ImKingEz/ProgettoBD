PGDMP      3                {            PROGETTO    16.1    16.1 I    O           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            P           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            Q           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            R           1262    16450    PROGETTO    DATABASE     }   CREATE DATABASE "PROGETTO" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Italian_Italy.1252';
    DROP DATABASE "PROGETTO";
                postgres    false                        2615    16492    wiki    SCHEMA        CREATE SCHEMA wiki;
    DROP SCHEMA wiki;
                postgres    false            _           1247    16498 	   maxlength    DOMAIN     A   CREATE DOMAIN wiki.maxlength AS character varying(100) NOT NULL;
    DROP DOMAIN wiki.maxlength;
       wiki          postgres    false    6            b           1247    25026    vartype    DOMAIN     >   CREATE DOMAIN wiki.vartype AS character varying(15) NOT NULL;
    DROP DOMAIN wiki.vartype;
       wiki          postgres    false    6            �            1255    25227    aggiornaultimamodifica()    FUNCTION     �  CREATE FUNCTION wiki.aggiornaultimamodifica() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    idPaginaAppoggio int;
    testoappoggio  varchar(100);
    indiceappoggio int;
    idPaginaAppoggioFrase  int;
    testoProposto  varchar(100);
BEGIN
    -- Trovo la pagina in cui è stata effettuata la valutazione
    SELECT p.idpagina
    into idPaginaAppoggio
    FROM pagina p, utente u, valutazione v
    where p.usernameAutore = u.username and u.username = v.usernameAutore and v.idvalutazione = new.idvalutazione;

    -- Aggiorno l'ultima modifica della pagina poichè la valutazione è stata accettata
    UPDATE pagina
    SET dataUltimaModifica = new.dataValutazione, oraUltimaModifica = new.oraValutazione
    WHERE idPaginaAppoggio = idPagina;

    SELECT f.testo,f.indice,f.idpagina,m.testo as testoprop
    into testoAppoggio,indiceAppoggio,idPaginaAppoggioFrase,testoProposto
    FROM frase f, modifica m, valutazione v
    where f.testo = m.testofrase and f.indice=m.indice and f.idpagina=m.idPaginaFrase
    and m.idmodifica=v.idModifica and v.idvalutazione = new.idvalutazione;

    -- Creo la nuova frase con lo stesso indice
    insert into frase (testo,indice,idpagina) values (testoProposto,indiceAppoggio,idPaginaAppoggio);

    return NEW;
end;
$$;
 -   DROP FUNCTION wiki.aggiornaultimamodifica();
       wiki          postgres    false    6            �            1255    16612     aggiornaultimamodificafunction()    FUNCTION     <  CREATE FUNCTION wiki.aggiornaultimamodificafunction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    idPaginaAppoggio int;
    testoappoggio  varchar(100);
    indiceappoggio int;
    idPaginaAppoggioFrase  int;
    testoProposto  varchar(100);
BEGIN
    SELECT p.idpagina
    into idPaginaAppoggio
    FROM pagina p, utente u, valutazione v
    where p.usernameAutore = u.username and u.username = v.usernameAutore and v.idvalutazione = new.idvalutazione;

    UPDATE pagina
    SET dataUltimaModifica = new.dataValutazione, oraUltimaModifica = new.oraValutazione
    WHERE idPaginaAppoggio = idPagina;

    SELECT f.testo,f.indice,f.idpagina,m.testo as testoprop
    into testoAppoggio,indiceAppoggio,idPaginaAppoggioFrase,testoProposto
    FROM frase f, modifica m, valutazione v
    where f.testo = m.testofrase and f.indice=m.indice and f.idpagina=m.idPaginaFrase
    and m.idmodifica=v.idModifica and v.idvalutazione = new.idvalutazione;
	
	insert into frase (testo,indice,idpagina) values (testoProposto,indiceAppoggio,idPaginaAppoggio);
	
    return NEW;
end;
$$;
 5   DROP FUNCTION wiki.aggiornaultimamodificafunction();
       wiki          postgres    false    6            �            1255    25223 !   coerenzadatavalutazionefunction()    FUNCTION     .  CREATE FUNCTION wiki.coerenzadatavalutazionefunction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
dataAppoggiomod date;
oraAppoggiomod time;
BEGIN
    select m.dataModificaproposta , m.oramodificaproposta
    into dataAppoggiomod,oraAppoggiomod
    from valutazione v, modifica m
    where new.idmodifica = m.idmodifica and new.idvalutazione=v.idvalutazione;

    if(new.datavalutazione < dataAppoggiomod or (new.datavalutazione = dataAppoggiomod and new.oravalutazione < oraAppoggiomod)) then
        RAISE EXCEPTION 'ATTENZIONE DATE NON COERENTI, RIPROVA!';
        --poichè non è possibile che una frase sia valutata prima della  modifica stessa
    end if;

    -- Altrimenti l'inserimento continuerà senza problemi

    RAISE NOTICE 'Date coerenti puoi continuare!';

    return NEW;

END;
$$;
 6   DROP FUNCTION wiki.coerenzadatavalutazionefunction();
       wiki          postgres    false    6            �            1255    25275    correzionevalutazionifunction()    FUNCTION     �  CREATE FUNCTION wiki.correzionevalutazionifunction() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE

    idModificaAppoggio int;
	
	paginaRef int;

    --Le modifiche non ancora valutate
    modificheNonValutate refcursor;
	
	comandosql text:='select m.idmodifica, m.testo, m.dataModificaProposta, m.oraModificaProposta, m.username, m.testofrase, m.indice, m.idpaginafrase
    from modifica m
    where m.idpaginafrase = $1 and m.idmodifica not in (select v.idmodifica
                                                        from valutazione v)';

    modificaCorrente modifica%rowtype;

    datamin date;

    oraMin time;
	
	pagAppoggio int;

BEGIN

	select m.idpaginafrase into paginaRef
	from modifica m
	where new.idmodifica=m.idmodifica;
														
    OPEN modificheNonValutate FOR EXECUTE comandosql USING paginaRef;

    --Metto in dataMin e oraMin la data e l'ora della modifica a cui è riferita la valutazione
    select m.dataModificaProposta, m.oraModificaProposta, m.idpaginafrase into dataMin, oraMin, pagAppoggio
    from modifica m
    where new.idmodifica=m.idmodifica;

    loop

    FETCH modificheNonValutate INTO modificaCorrente;

    if not found then
     EXIT;
    end if;

     if(modificaCorrente.dataModificaProposta < dataMin or 
       ((modificaCorrente.dataModificaProposta = dataMin) and (modificaCorrente.oraModificaProposta < oraMin))) then

       dataMin:=modificaCorrente.dataModificaProposta;
       oramin:=modificaCorrente.oramodificaProposta;

     end if;

    end loop;

    select m.idmodifica into idModificaAppoggio
    from modifica m
    where m.dataModificaProposta = datamin and m.oraModificaProposta = oramin and m.idpaginafrase = pagAppoggio;

    if new.idmodifica = idModificaAppoggio then 
        RAISE NOTICE 'Perfetto la data coincide con la data minore non ancora valutata';
        RETURN NEW;
    else
        RAISE EXCEPTION 'ATTENZIONE LA DATA NON E LA MINORE, RIPROVA!';
    end if;

    close modificheNonValutate;

end;
$_$;
 4   DROP FUNCTION wiki.correzionevalutazionifunction();
       wiki          postgres    false    6            �            1255    16625    inserimentofrasefunction()    FUNCTION     �  CREATE FUNCTION wiki.inserimentofrasefunction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    countAppoggio int;
    maxIndiceAppoggio int;
    countAppoggioIndice int;
BEGIN

    -- Controllo quante frasi hanno questo indice
    SELECT count(*) into countAppoggioIndice
    FROM frase
    WHERE new.idpagina=idpagina and new.indice=indice;

    -- Se ci sono altre frasi con lo stesso indice allora questa sarà una modifica
    if countAppoggioIndice > 1 then 
        return new;
    end if;

    -- Se non è stato specificato l'indice la frase non è una modifica e il suo indice sarà di default = 0
    -- Conto quante frasi ci sono nella pagina
    SELECT count(*) into countAppoggio
    FROM frase
    WHERE new.idpagina=idpagina;

    -- Se la frase è l'unica allora il suo indice sarà 1
    if countAppoggio = 1 then 
        UPDATE frase
        SET indice = 1
        WHERE new.idpagina=idpagina;
    else -- Altrimenti sarà uguale all'indice massimo + 1
        SELECT MAX(indice) into maxIndiceappoggio 
        FROM frase
        WHERE new.idpagina=idpagina;

        UPDATE frase
        SET indice = maxIndiceAppoggio + 1
        WHERE new.idpagina=idpagina and new.testo=testo and new.indice=indice;
    end if;

    return NEW;
end;
$$;
 /   DROP FUNCTION wiki.inserimentofrasefunction();
       wiki          postgres    false    6            �            1255    16614    inserimentopaginafunction()    FUNCTION     �  CREATE FUNCTION wiki.inserimentopaginafunction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Quando la pagina è stata appena creata la data (e ora) di ultima modifica viene impostata
    -- alla data (e ora) di creazione
    UPDATE pagina 
    SET dataultimamodifica = new.datacreazione, oraultimamodifica = new.oracreazione
    where idpagina = new.idpagina;

    return NEW;
end;
$$;
 0   DROP FUNCTION wiki.inserimentopaginafunction();
       wiki          postgres    false    6            �            1255    24822    modificadellautorefunction()    FUNCTION       CREATE FUNCTION wiki.modificadellautorefunction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
autore varchar(15);
BEGIN
    select p.usernameautore
    into autore
    from frase f, pagina p
    where new.testofrase = f.testo and new.indice = f.indice and f.idpagina = new.idpaginafrase and f.idpagina = p.idpagina;

    if(autore <> new.username) then
        return NEW;
    end if;

    -- L'Autore è lo stesso che ha proposto la modifica quindi sarà accettata in automatico

    insert into valutazione(accettazione, datavalutazione, oravalutazione, usernameautore, idmodifica)
    values('true', new.datamodificaproposta, new.oramodificaproposta, autore, new.idmodifica);
    RAISE NOTICE 'Modifica accettata in automatico';

    return NEW;

END;
$$;
 1   DROP FUNCTION wiki.modificadellautorefunction();
       wiki          postgres    false    6            �            1255    25238    numeroindici(integer)    FUNCTION     .  CREATE FUNCTION wiki.numeroindici(idpaginput integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE

    numeroIndici int;

    countAppoggio int;

    indici cursor for
    SELECT f.indice
    FROM frase f
    WHERE f.idpagina=idpaginput;
    indiceCorrente int;

BEGIN

    numeroIndici := 0;

    -- Questa tabella serve a tenere traccia degli indici già visitati
    execute 'create table IndiciVisitati (indice int)';

    open indici;

    loop

        fetch indici into indiceCorrente;

        IF NOT FOUND THEN
            EXIT;
        END IF;

        select count(*) into countAppoggio
        from IndiciVisitati i
        where i.indice=indiceCorrente;

        -- Controllo se ho già visitato questo indice, in tal caso vado al prossimo loop
        if countAppoggio>0 then
            continue;
        end if;
        
        numeroIndici := numeroIndici + 1;
        --faccio una sorta di count per vedere quanti indici distinti ho

        insert into IndiciVisitati (indice) values (indiceCorrente);
        --ogni volta che visito un'indice lo inserisco nella tabella

    end loop;

    close indici;

    execute 'DROP TABLE Indicivisitati';
    -- Elimino la tabella temporanea, altrimenti rimarrebbe in memoria fino 
        -- alla chiusura della sessione

RETURN numeroIndici;

END
$$;
 5   DROP FUNCTION wiki.numeroindici(idpaginput integer);
       wiki          postgres    false    6            �            1255    25235 '   numeromodificheindice(integer, integer)    FUNCTION     �  CREATE FUNCTION wiki.numeromodificheindice(idpaginput integer, indiceinput integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE

    numeroIndici int;

BEGIN

    numeroIndici:=0;
    
    SELECT count(*) into numeroIndici
    FROM frase f
    WHERE idpagInput=f.idpagina and f.indice=indiceInput;

    RETURN numeroIndici-1;
    --ritorno il numero di indici - 1 poichè ovviamente questa query mi conta anche l'indice corrente, quindi va sottratto

END
$$;
 S   DROP FUNCTION wiki.numeromodificheindice(idpaginput integer, indiceinput integer);
       wiki          postgres    false    6            �            1255    25143 #   stampaultimaversionepagina(integer) 	   PROCEDURE     c  CREATE PROCEDURE wiki.stampaultimaversionepagina(IN idpaginput integer)
    LANGUAGE plpgsql
    AS $$
DECLARE 
	countAppoggio int;
	testoAppoggio varchar(100);
	indiceAppoggio int;
	idPaginaAppoggio int;
	controllo int;
	-- Questo cursore ad ogni fetch restituisce il testo, l'indice e 
        -- l'idpagina di ogni frase ordinate per l'indice
	frasiPagina cursor for 
	select f.testo,f.indice,f.idpagina
    from frase f left join modifica m on (f.idpagina = idpaginput and f.idpagina = m.idpaginafrase and f.testo = m.testofrase and f.indice = m.indice)
         left join valutazione v on (v.idmodifica = m.idmodifica and accettazione = true)
    order by f.indice asc, m.datamodificaproposta asc, m.oramodificaproposta asc;
	fraseCorrente frase%rowtype; 
	
BEGIN

	RAISE NOTICE 'Frasi della pagina: %', idpagInput;

	-- Questa tabella serve a tenere traccia degli indici già visitati
	execute 'create table IndiciVisitati (indice int)';

	open frasiPagina;
	
	loop
	
	controllo:=0;
	
	fetch frasiPagina into fraseCorrente;
	
	IF NOT FOUND THEN
        EXIT;
    END IF;

		select count(*) into countAppoggio
		from IndiciVisitati i
		where i.indice=fraseCorrente.indice;
					
		-- Controllo se ho già visitato questo indice, in tal 
            --caso salto il loop corrente
		if countAppoggio>0 then
			continue;
		end if;
	
		-- Conto quante frasi hanno lo stesso indice
		SELECT count(*) into countAppoggio
		FROM frase f
		WHERE idpagInput=f.idpagina and f.indice=fraseCorrente.indice;
		
		-- Se c'è più di una frase con lo stesso indice allora controllerò 
            -- quale sarà l'ultima valutata
		if countAppoggio > 1 then 
			select m.testo, m.indice, m.idpaginafrase into testoAppoggio,indiceAppoggio,idpaginaAppoggio
			from frase f join modifica m on (f.idpagina = idpaginput and f.indice = fraseCorrente.indice and f.idpagina = m.idpaginafrase and f.testo = m.testofrase and f.indice = m.indice)
                 join valutazione v on (v.idmodifica = m.idmodifica and v.accettazione = true)
            order by f.indice asc, v.datavalutazione desc, v.oravalutazione desc LIMIT 1;
			
			controllo = 1;
		
		end if;
		
		insert into IndiciVisitati (indice) values (fraseCorrente.indice);
		
		-- Se il controllo sarà 0 vorrà dire che non ci sono più frasi con lo 
        -- stesso indice, altrimenti stampo quella appropriata
		if controllo = 0 then 
			RAISE NOTICE 'testo: %', fraseCorrente.testo;
			RAISE NOTICE 'indice: %', fraseCorrente.indice;
			RAISE NOTICE 'idpagina: %', fraseCorrente.idpagina;
		elsif controllo = 1 then 
			RAISE NOTICE 'testo: %', testoAppoggio;
			RAISE NOTICE 'indice: %', indiceAppoggio;
			RAISE NOTICE 'idpagina: %', idPaginaAppoggio;
		end if;
	
	end loop;
	
	close frasiPagina;
	
	-- Elimino la tabella temporanea, altrimenti rimarrebbe in memoria fino 
        -- alla chiusura della sessione
	execute 'DROP TABLE Indicivisitati';
	
END;
$$;
 G   DROP PROCEDURE wiki.stampaultimaversionepagina(IN idpaginput integer);
       wiki          postgres    false    6            �            1255    25142 >   stampaunaversionepagina(integer, date, time without time zone) 	   PROCEDURE       CREATE PROCEDURE wiki.stampaunaversionepagina(IN idpaginput integer, IN datainput date, IN orainput time without time zone)
    LANGUAGE plpgsql
    AS $$
DECLARE 
	countAppoggio int;
	testoAppoggio varchar(100);
	indiceAppoggio int;
	idPaginaAppoggio int;
	controllo int;
	-- Questo cursore ad ogni fetch restituisce il testo, l'indice e 
        -- l'idpagina di ogni frase ordinate per l'indice
	frasiPagina cursor for 
	select f.testo,f.indice,f.idpagina
    from frase f left join modifica m on (f.idpagina = idpaginput and f.idpagina = m.idpaginafrase and f.testo = m.testofrase and f.indice = m.indice)
         left join valutazione v on (v.idmodifica = m.idmodifica and accettazione = true)
    order by f.indice asc, m.datamodificaproposta asc, m.oramodificaproposta asc;
	fraseCorrente frase%rowtype; 
	
BEGIN

	RAISE NOTICE 'Frasi della pagina: %', idpagInput;

	-- Questa tabella serve a tenere traccia degli indici già visitati
	execute 'create table IndiciVisitati (indice int)';

	open frasiPagina;
	
	loop
	
	controllo:=0;
	
	fetch frasiPagina into fraseCorrente;
	
	IF NOT FOUND THEN
        EXIT;
    END IF;

		select count(*) into countAppoggio
		from IndiciVisitati i
		where i.indice=fraseCorrente.indice;
					
		-- Controllo se ho già visitato questo indice, in tal 
            --caso salto il loop corrente
		if countAppoggio>0 then
			continue;
		end if;
	
		-- Conto quante frasi hanno lo stesso indice
		SELECT count(*) into countAppoggio
		FROM frase f
		WHERE idpagInput=f.idpagina and f.indice=fraseCorrente.indice;
		
		-- Se c'è più di una frase con lo stesso indice allora controllerò 
            -- quale sarà l'ultima valutata
		if countAppoggio > 1 then 
			select m.testo, m.indice, m.idpaginafrase into testoAppoggio,indiceAppoggio,idpaginaAppoggio
			from frase f join modifica m on (f.idpagina = idpaginput and f.indice = fraseCorrente.indice and f.idpagina = m.idpaginafrase and f.testo = m.testofrase and f.indice = m.indice)
                 join valutazione v on (v.idmodifica = m.idmodifica and v.accettazione = true)
			where v.datavalutazione < dataInput or (v.datavalutazione = dataInput and v.oravalutazione < oraInput)
            order by f.indice asc, v.datavalutazione desc, v.oravalutazione desc LIMIT 1;
			
			controllo = 1;
		
		end if;
		
		insert into IndiciVisitati (indice) values (fraseCorrente.indice);
		
		-- Se il controllo sarà 0 vorrà dire che non ci sono più frasi con lo 
        -- stesso indice, altrimenti stampo quella appropriata
		if controllo = 0 then 
			RAISE NOTICE 'testo: %', fraseCorrente.testo;
			RAISE NOTICE 'indice: %', fraseCorrente.indice;
			RAISE NOTICE 'idpagina: %', fraseCorrente.idpagina;
		elsif controllo = 1 then 
			RAISE NOTICE 'testo: %', testoAppoggio;
			RAISE NOTICE 'indice: %', indiceAppoggio;
			RAISE NOTICE 'idpagina: %', idPaginaAppoggio;
		end if;
	
	end loop;
	
	close frasiPagina;
	
	-- Elimino la tabella temporanea, altrimenti rimarrebbe in memoria fino 
        -- alla chiusura della sessione
	execute 'DROP TABLE Indicivisitati';
	
END;
$$;
 {   DROP PROCEDURE wiki.stampaunaversionepagina(IN idpaginput integer, IN datainput date, IN orainput time without time zone);
       wiki          postgres    false    6            �            1255    25233    stampautentieautori() 	   PROCEDURE     �  CREATE PROCEDURE wiki.stampautentieautori()
    LANGUAGE plpgsql
    AS $$
DECLARE 

    autori cursor for
    SELECT distinct u.username
    FROM utente u,pagina p
    WHERE u.username=p.usernameAutore;
    autoreCorrente varchar(15);

    utenti cursor for
    SELECT u.username
    FROM utente u
    WHERE u.username not in ( SELECT p.usernameautore
                              FROM pagina p);
    utenteCorrente varchar(15);

BEGIN

    open autori;

    RAISE NOTICE 'Gli utenti creatori di almeno una pagina sono : ';

    loop

        fetch autori into autoreCorrente;

        IF NOT FOUND THEN
            EXIT;
        END IF;

        RAISE NOTICE '-%',autoreCorrente;

    end loop;

    close autori;

    open utenti;

    RAISE NOTICE 'Gli utenti del sistema sono : ';

    loop

        fetch utenti into utenteCorrente;

        IF NOT FOUND THEN
            EXIT;
        END IF;

        RAISE NOTICE '-%',utenteCorrente;

    end loop;

    close utenti;

END
$$;
 +   DROP PROCEDURE wiki.stampautentieautori();
       wiki          postgres    false    6            �            1255    25286    verificaautorefunction()    FUNCTION     �  CREATE FUNCTION wiki.verificaautorefunction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE

	pagineAutore cursor for
	select p.idpagina
	from utente u, pagina p
	where new.usernameautore=u.username and u.username=p.usernameautore;
	paginaCorrente int;
	
	paginaAppoggio int;
	
	controllo int;
	
BEGIN
	
	controllo:=0;
	
    select m.idpaginafrase into paginaAppoggio
    from modifica m
    where new.idmodifica=m.idmodifica;
	
	open pagineAutore;
	
	loop
	
	fetch pagineAutore into paginaCorrente;
	
	if not found then
     EXIT;
    end if;
	
	--Controllo se l'autore delle pagine coincide con quello inserito, prenendolo dalla modifica associata alla valutazione
	if paginaCorrente = paginaAppoggio then
		controllo:=1;
	end if;
	
	end loop;
	
	if controllo = 1 then
		RAISE NOTICE 'Perfetto puoi continuare l autore e corretto';
        RETURN NEW;
	else 
		RAISE EXCEPTION 'ATTENZIONE L AUTORE CHE HAI INSERITO NON E IL CREATORE DELLA PAGINA, RIPROVA!';
	end if;
	
	close pagineAutore;
	
end;
$$;
 -   DROP FUNCTION wiki.verificaautorefunction();
       wiki          postgres    false    6            �            1259    25051    cercare    TABLE     a   CREATE TABLE wiki.cercare (
    username wiki.vartype NOT NULL,
    idpagina integer NOT NULL
);
    DROP TABLE wiki.cercare;
       wiki         heap    postgres    false    866    6            �            1259    25068    frase    TABLE     �   CREATE TABLE wiki.frase (
    testo wiki.maxlength NOT NULL,
    indice integer DEFAULT 0 NOT NULL,
    idpagina integer NOT NULL,
    CONSTRAINT checktesto CHECK ((length((testo)::text) > 0))
);
    DROP TABLE wiki.frase;
       wiki         heap    postgres    false    6    863            �            1259    25123    linkare    TABLE     �   CREATE TABLE wiki.linkare (
    idpaginalinkata integer NOT NULL,
    idpaginafrase integer NOT NULL,
    testo wiki.maxlength NOT NULL,
    indice integer NOT NULL,
    CONSTRAINT checklinkpagina CHECK ((idpaginalinkata <> idpaginafrase))
);
    DROP TABLE wiki.linkare;
       wiki         heap    postgres    false    6    863            �            1259    25084    modifica    TABLE     �  CREATE TABLE wiki.modifica (
    idmodifica integer NOT NULL,
    testo wiki.maxlength,
    datamodificaproposta date DEFAULT CURRENT_DATE NOT NULL,
    oramodificaproposta time without time zone DEFAULT CURRENT_TIME NOT NULL,
    username wiki.vartype,
    testofrase wiki.maxlength,
    indice integer NOT NULL,
    idpaginafrase integer NOT NULL,
    CONSTRAINT checkfrasidiverse CHECK (((testo)::text <> (testofrase)::text)),
    CONSTRAINT checktesto CHECK ((length((testo)::text) > 0))
);
    DROP TABLE wiki.modifica;
       wiki         heap    postgres    false    863    866    863    6            �            1259    25083    modifica_idmodifica_seq    SEQUENCE     �   CREATE SEQUENCE wiki.modifica_idmodifica_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE wiki.modifica_idmodifica_seq;
       wiki          postgres    false    222    6            S           0    0    modifica_idmodifica_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE wiki.modifica_idmodifica_seq OWNED BY wiki.modifica.idmodifica;
          wiki          postgres    false    221            �            1259    25036    pagina    TABLE       CREATE TABLE wiki.pagina (
    idpagina integer NOT NULL,
    titolo wiki.vartype,
    datacreazione date DEFAULT CURRENT_DATE NOT NULL,
    oracreazione time without time zone DEFAULT CURRENT_TIME NOT NULL,
    dataultimamodifica date,
    oraultimamodifica time without time zone,
    usernameautore wiki.vartype,
    CONSTRAINT checkdate CHECK (((dataultimamodifica > datacreazione) OR ((dataultimamodifica = datacreazione) AND (oraultimamodifica >= oracreazione)))),
    CONSTRAINT checktitolo CHECK ((length((titolo)::text) > 2))
);
    DROP TABLE wiki.pagina;
       wiki         heap    postgres    false    866    866    6            �            1259    25035    pagina_idpagina_seq    SEQUENCE     �   CREATE SEQUENCE wiki.pagina_idpagina_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE wiki.pagina_idpagina_seq;
       wiki          postgres    false    6    218            T           0    0    pagina_idpagina_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE wiki.pagina_idpagina_seq OWNED BY wiki.pagina.idpagina;
          wiki          postgres    false    217            �            1259    25027    utente    TABLE     �   CREATE TABLE wiki.utente (
    username wiki.vartype NOT NULL,
    password wiki.vartype,
    CONSTRAINT "checkLengthPassword" CHECK ((length((password)::text) > 5))
);
    DROP TABLE wiki.utente;
       wiki         heap    postgres    false    866    6    866            �            1259    25105    valutazione    TABLE     ,  CREATE TABLE wiki.valutazione (
    idvalutazione integer NOT NULL,
    accettazione boolean NOT NULL,
    datavalutazione date DEFAULT CURRENT_DATE NOT NULL,
    oravalutazione time without time zone DEFAULT CURRENT_TIME NOT NULL,
    usernameautore wiki.vartype,
    idmodifica integer NOT NULL
);
    DROP TABLE wiki.valutazione;
       wiki         heap    postgres    false    866    6            �            1259    25104    valutazione_idvalutazione_seq    SEQUENCE     �   CREATE SEQUENCE wiki.valutazione_idvalutazione_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE wiki.valutazione_idvalutazione_seq;
       wiki          postgres    false    6    224            U           0    0    valutazione_idvalutazione_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE wiki.valutazione_idvalutazione_seq OWNED BY wiki.valutazione.idvalutazione;
          wiki          postgres    false    223            �           2604    25087    modifica idmodifica    DEFAULT     v   ALTER TABLE ONLY wiki.modifica ALTER COLUMN idmodifica SET DEFAULT nextval('wiki.modifica_idmodifica_seq'::regclass);
 @   ALTER TABLE wiki.modifica ALTER COLUMN idmodifica DROP DEFAULT;
       wiki          postgres    false    221    222    222            ~           2604    25039    pagina idpagina    DEFAULT     n   ALTER TABLE ONLY wiki.pagina ALTER COLUMN idpagina SET DEFAULT nextval('wiki.pagina_idpagina_seq'::regclass);
 <   ALTER TABLE wiki.pagina ALTER COLUMN idpagina DROP DEFAULT;
       wiki          postgres    false    218    217    218            �           2604    25108    valutazione idvalutazione    DEFAULT     �   ALTER TABLE ONLY wiki.valutazione ALTER COLUMN idvalutazione SET DEFAULT nextval('wiki.valutazione_idvalutazione_seq'::regclass);
 F   ALTER TABLE wiki.valutazione ALTER COLUMN idvalutazione DROP DEFAULT;
       wiki          postgres    false    223    224    224            F          0    25051    cercare 
   TABLE DATA           3   COPY wiki.cercare (username, idpagina) FROM stdin;
    wiki          postgres    false    219   �       G          0    25068    frase 
   TABLE DATA           6   COPY wiki.frase (testo, indice, idpagina) FROM stdin;
    wiki          postgres    false    220   ,�       L          0    25123    linkare 
   TABLE DATA           N   COPY wiki.linkare (idpaginalinkata, idpaginafrase, testo, indice) FROM stdin;
    wiki          postgres    false    225   ��       I          0    25084    modifica 
   TABLE DATA           �   COPY wiki.modifica (idmodifica, testo, datamodificaproposta, oramodificaproposta, username, testofrase, indice, idpaginafrase) FROM stdin;
    wiki          postgres    false    222   ��       E          0    25036    pagina 
   TABLE DATA           �   COPY wiki.pagina (idpagina, titolo, datacreazione, oracreazione, dataultimamodifica, oraultimamodifica, usernameautore) FROM stdin;
    wiki          postgres    false    218   ��       C          0    25027    utente 
   TABLE DATA           2   COPY wiki.utente (username, password) FROM stdin;
    wiki          postgres    false    216   �       K          0    25105    valutazione 
   TABLE DATA           }   COPY wiki.valutazione (idvalutazione, accettazione, datavalutazione, oravalutazione, usernameautore, idmodifica) FROM stdin;
    wiki          postgres    false    224   &�       V           0    0    modifica_idmodifica_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('wiki.modifica_idmodifica_seq', 23, true);
          wiki          postgres    false    221            W           0    0    pagina_idpagina_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('wiki.pagina_idpagina_seq', 9, true);
          wiki          postgres    false    217            X           0    0    valutazione_idvalutazione_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('wiki.valutazione_idvalutazione_seq', 97, true);
          wiki          postgres    false    223            �           2606    25034    utente pkUtente 
   CONSTRAINT     S   ALTER TABLE ONLY wiki.utente
    ADD CONSTRAINT "pkUtente" PRIMARY KEY (username);
 9   ALTER TABLE ONLY wiki.utente DROP CONSTRAINT "pkUtente";
       wiki            postgres    false    216            �           2606    25057    cercare pkcercare 
   CONSTRAINT     ]   ALTER TABLE ONLY wiki.cercare
    ADD CONSTRAINT pkcercare PRIMARY KEY (username, idpagina);
 9   ALTER TABLE ONLY wiki.cercare DROP CONSTRAINT pkcercare;
       wiki            postgres    false    219    219            �           2606    25075    frase pkfrase 
   CONSTRAINT     ^   ALTER TABLE ONLY wiki.frase
    ADD CONSTRAINT pkfrase PRIMARY KEY (testo, indice, idpagina);
 5   ALTER TABLE ONLY wiki.frase DROP CONSTRAINT pkfrase;
       wiki            postgres    false    220    220    220            �           2606    25130    linkare pklinkare 
   CONSTRAINT     x   ALTER TABLE ONLY wiki.linkare
    ADD CONSTRAINT pklinkare PRIMARY KEY (idpaginalinkata, idpaginafrase, testo, indice);
 9   ALTER TABLE ONLY wiki.linkare DROP CONSTRAINT pklinkare;
       wiki            postgres    false    225    225    225    225            �           2606    25093    modifica pkmodifica 
   CONSTRAINT     W   ALTER TABLE ONLY wiki.modifica
    ADD CONSTRAINT pkmodifica PRIMARY KEY (idmodifica);
 ;   ALTER TABLE ONLY wiki.modifica DROP CONSTRAINT pkmodifica;
       wiki            postgres    false    222            �           2606    25045    pagina pkpagina 
   CONSTRAINT     Q   ALTER TABLE ONLY wiki.pagina
    ADD CONSTRAINT pkpagina PRIMARY KEY (idpagina);
 7   ALTER TABLE ONLY wiki.pagina DROP CONSTRAINT pkpagina;
       wiki            postgres    false    218            �           2606    25112    valutazione pkvalutazione 
   CONSTRAINT     `   ALTER TABLE ONLY wiki.valutazione
    ADD CONSTRAINT pkvalutazione PRIMARY KEY (idvalutazione);
 A   ALTER TABLE ONLY wiki.valutazione DROP CONSTRAINT pkvalutazione;
       wiki            postgres    false    224            �           2606    25284    modifica uniquedate 
   CONSTRAINT     �   ALTER TABLE ONLY wiki.modifica
    ADD CONSTRAINT uniquedate UNIQUE (datamodificaproposta, oramodificaproposta, idpaginafrase);
 ;   ALTER TABLE ONLY wiki.modifica DROP CONSTRAINT uniquedate;
       wiki            postgres    false    222    222    222            �           2606    25077    frase uniquefrase 
   CONSTRAINT     U   ALTER TABLE ONLY wiki.frase
    ADD CONSTRAINT uniquefrase UNIQUE (testo, idpagina);
 9   ALTER TABLE ONLY wiki.frase DROP CONSTRAINT uniquefrase;
       wiki            postgres    false    220    220            �           2606    25282    valutazione uniqueidvalutazione 
   CONSTRAINT     ^   ALTER TABLE ONLY wiki.valutazione
    ADD CONSTRAINT uniqueidvalutazione UNIQUE (idmodifica);
 G   ALTER TABLE ONLY wiki.valutazione DROP CONSTRAINT uniqueidvalutazione;
       wiki            postgres    false    224            �           2620    25145 "   valutazione aggiornaultimamodifica    TRIGGER     �   CREATE TRIGGER aggiornaultimamodifica AFTER INSERT OR UPDATE OF accettazione ON wiki.valutazione FOR EACH ROW WHEN ((new.accettazione = true)) EXECUTE FUNCTION wiki.aggiornaultimamodificafunction();
 9   DROP TRIGGER aggiornaultimamodifica ON wiki.valutazione;
       wiki          postgres    false    224    238    224    224            �           2620    25229 #   valutazione coerenzadatavalutazione    TRIGGER     �   CREATE TRIGGER coerenzadatavalutazione AFTER INSERT OR UPDATE ON wiki.valutazione FOR EACH ROW EXECUTE FUNCTION wiki.coerenzadatavalutazionefunction();
 :   DROP TRIGGER coerenzadatavalutazione ON wiki.valutazione;
       wiki          postgres    false    224    242            �           2620    25276 !   valutazione correzionevalutazioni    TRIGGER     �   CREATE TRIGGER correzionevalutazioni AFTER INSERT ON wiki.valutazione FOR EACH ROW EXECUTE FUNCTION wiki.correzionevalutazionifunction();
 8   DROP TRIGGER correzionevalutazioni ON wiki.valutazione;
       wiki          postgres    false    224    249            �           2620    25147    frase inserimentofrase    TRIGGER     z   CREATE TRIGGER inserimentofrase AFTER INSERT ON wiki.frase FOR EACH ROW EXECUTE FUNCTION wiki.inserimentofrasefunction();
 -   DROP TRIGGER inserimentofrase ON wiki.frase;
       wiki          postgres    false    239    220            �           2620    25144    pagina inserimentopagina    TRIGGER     }   CREATE TRIGGER inserimentopagina AFTER INSERT ON wiki.pagina FOR EACH ROW EXECUTE FUNCTION wiki.inserimentopaginafunction();
 /   DROP TRIGGER inserimentopagina ON wiki.pagina;
       wiki          postgres    false    218    226            �           2620    25146    modifica modificadellautore    TRIGGER     �   CREATE TRIGGER modificadellautore AFTER INSERT OR UPDATE ON wiki.modifica FOR EACH ROW EXECUTE FUNCTION wiki.modificadellautorefunction();
 2   DROP TRIGGER modificadellautore ON wiki.modifica;
       wiki          postgres    false    222    240            �           2620    25287    valutazione verificaautore    TRIGGER     �   CREATE TRIGGER verificaautore AFTER INSERT OR UPDATE ON wiki.valutazione FOR EACH ROW EXECUTE FUNCTION wiki.verificaautorefunction();
 1   DROP TRIGGER verificaautore ON wiki.valutazione;
       wiki          postgres    false    247    224            �           2606    25046    pagina fkautore    FK CONSTRAINT     �   ALTER TABLE ONLY wiki.pagina
    ADD CONSTRAINT fkautore FOREIGN KEY (usernameautore) REFERENCES wiki.utente(username) ON UPDATE CASCADE ON DELETE SET NULL;
 7   ALTER TABLE ONLY wiki.pagina DROP CONSTRAINT fkautore;
       wiki          postgres    false    4752    218    216            �           2606    25113    valutazione fkautore    FK CONSTRAINT     �   ALTER TABLE ONLY wiki.valutazione
    ADD CONSTRAINT fkautore FOREIGN KEY (usernameautore) REFERENCES wiki.utente(username) ON UPDATE CASCADE ON DELETE SET NULL;
 <   ALTER TABLE ONLY wiki.valutazione DROP CONSTRAINT fkautore;
       wiki          postgres    false    4752    224    216            �           2606    25099    modifica fkfrase    FK CONSTRAINT     �   ALTER TABLE ONLY wiki.modifica
    ADD CONSTRAINT fkfrase FOREIGN KEY (testofrase, indice, idpaginafrase) REFERENCES wiki.frase(testo, indice, idpagina) ON UPDATE CASCADE ON DELETE SET NULL;
 8   ALTER TABLE ONLY wiki.modifica DROP CONSTRAINT fkfrase;
       wiki          postgres    false    220    222    4758    220    222    220    222            �           2606    25136    linkare fkfrase    FK CONSTRAINT     �   ALTER TABLE ONLY wiki.linkare
    ADD CONSTRAINT fkfrase FOREIGN KEY (idpaginafrase, testo, indice) REFERENCES wiki.frase(idpagina, testo, indice) ON UPDATE CASCADE ON DELETE SET NULL;
 7   ALTER TABLE ONLY wiki.linkare DROP CONSTRAINT fkfrase;
       wiki          postgres    false    225    4758    220    220    220    225    225            �           2606    25118    valutazione fkmodifica    FK CONSTRAINT     �   ALTER TABLE ONLY wiki.valutazione
    ADD CONSTRAINT fkmodifica FOREIGN KEY (idmodifica) REFERENCES wiki.modifica(idmodifica) ON UPDATE CASCADE ON DELETE SET NULL;
 >   ALTER TABLE ONLY wiki.valutazione DROP CONSTRAINT fkmodifica;
       wiki          postgres    false    222    224    4762            �           2606    25063    cercare fkpagina    FK CONSTRAINT     �   ALTER TABLE ONLY wiki.cercare
    ADD CONSTRAINT fkpagina FOREIGN KEY (idpagina) REFERENCES wiki.pagina(idpagina) ON UPDATE CASCADE ON DELETE SET NULL;
 8   ALTER TABLE ONLY wiki.cercare DROP CONSTRAINT fkpagina;
       wiki          postgres    false    218    4754    219            �           2606    25078    frase fkpagina    FK CONSTRAINT     �   ALTER TABLE ONLY wiki.frase
    ADD CONSTRAINT fkpagina FOREIGN KEY (idpagina) REFERENCES wiki.pagina(idpagina) ON UPDATE CASCADE ON DELETE SET NULL;
 6   ALTER TABLE ONLY wiki.frase DROP CONSTRAINT fkpagina;
       wiki          postgres    false    220    4754    218            �           2606    25131    linkare fkpagina    FK CONSTRAINT     �   ALTER TABLE ONLY wiki.linkare
    ADD CONSTRAINT fkpagina FOREIGN KEY (idpaginalinkata) REFERENCES wiki.pagina(idpagina) ON UPDATE CASCADE ON DELETE SET NULL;
 8   ALTER TABLE ONLY wiki.linkare DROP CONSTRAINT fkpagina;
       wiki          postgres    false    218    225    4754            �           2606    25058    cercare fkutente    FK CONSTRAINT     �   ALTER TABLE ONLY wiki.cercare
    ADD CONSTRAINT fkutente FOREIGN KEY (username) REFERENCES wiki.utente(username) ON UPDATE CASCADE ON DELETE SET NULL;
 8   ALTER TABLE ONLY wiki.cercare DROP CONSTRAINT fkutente;
       wiki          postgres    false    219    216    4752            �           2606    25094    modifica fkutente    FK CONSTRAINT     �   ALTER TABLE ONLY wiki.modifica
    ADD CONSTRAINT fkutente FOREIGN KEY (username) REFERENCES wiki.utente(username) ON UPDATE CASCADE ON DELETE SET NULL;
 9   ALTER TABLE ONLY wiki.modifica DROP CONSTRAINT fkutente;
       wiki          postgres    false    216    222    4752            F   -   x�K�KO����J�I+JM���JKL���e&��$1z\\\ ��      G   Z   x�+��4��J���4�%�%%���@V~J&D�,?='3_!)5/�/.)J��*�y���Vq&PJ!�8��jD$%�n|� f�"�      L      x������ � �      I   �   x�e�]� ���S�w��r����!AI=��Fꆧ��f�����r���$��@.�2���fX�n'���S��'�H��^�H4��*��i��Xto�L}#؂���Ɍ�,�0�c�T�E�.�����r�M����;l	�����<%���Y���ؠÿ�u
�Jp*�!l��&E�W�e�3�h      E   N   x�m�1� й��~P�gqibuAI���nX_�*=6�� A�J��HS����y'���oY�Q
�ld�~v>"3MLN      C   2   x�K�I+JM��,H,..�/J�J�KO�A��e&��$"�i�I�H�1z\\\ ���      K   v   x�e�;
�@��Zs��h_�Y�WC��I:{���?ӻ|���(uQk�*�}��_�hA����Tx��\��:�f���,�`r�v�0�˭3��ɰ��[$�M��9s�Fm������A�     