import unittest
import os
from unittest.mock import patch, MagicMock

import sqlalchemy

from container.cloud_sql.cloud_sql import init_connection_pool, init_db, fetchContext, storeEmbeddings


class TestDatabaseConnection(unittest.TestCase):
    def setUp(self):
        os.environ["PROJECT_ID"] = "project_id"
        os.environ["cloudsql_instance_region"] = "us-central1"
        os.environ["cloudsql_instance"] = "cloudsql-instance"
        os.environ["TABLE_NAME"] = "test_table"
        os.environ["DB_USER"] = "username"
        os.environ["DB_PASS"] = "password"

    @patch("app.Connector")
    def test_init_connection_pool(self, mock_connector):
        connection_pool = init_connection_pool(mock_connector)
        self.assertIsInstance(connection_pool, sqlalchemy.engine.base.Engine)

    @patch("app.sqlalchemy")
    @patch("app.pg8000")
    def test_init_db(self, mock_pg8000, mock_sqlalchemy):
        mock_connector = MagicMock()
        mock_connection = MagicMock()
        mock_connection.connect.return_value = mock_connection
        mock_connection.execute.return_value = None
        mock_connector.connect.return_value = mock_connection
        mock_sqlalchemy.create_engine.return_value = mock_connection

        init_db()

        mock_connector.connect.assert_called_once_with(
            "project_id:us-central1:cloudsql-instance",
            "pg8000",
            user="username",
            password="password",
            db="pgvector-database",
            ip_type="PRIVATE",
        )

    @patch("app.sqlalchemy")
    @patch("app.Transformer")
    def test_fetchContext(self, mock_transformer, mock_sqlalchemy):
        mock_connection = MagicMock()
        mock_connection.execute.return_value = [("test_text", [1, 2, 3])]
        mock_sqlalchemy.text.return_value = mock_connection

        mock_transformer.encode.return_value = [4, 5, 6]

        result = fetchContext("test_query")
        self.assertEqual(result, "test_text")

        mock_sqlalchemy.text.assert_called_once_with(
            "SELECT * FROM test_table"
        )
        mock_transformer.encode.assert_called_once_with("test_query")
        mock_connection.execute.assert_called_once_with(
            "SELECT id, text, text_embedding, 1 - ('[4,5,6]' <=> text_embedding) AS cosine_similarity FROM test_table ORDER BY cosine_similarity DESC LIMIT 5;"
        )

    @patch("app.sqlalchemy")
    @patch("app.Transformer")
    def test_fetchContext_with_empty_result(self, mock_transformer, mock_sqlalchemy):
        mock_connection = MagicMock()
        mock_connection.execute.return_value = []
        mock_sqlalchemy.text.return_value = mock_connection

        with self.assertRaises(ValueError) as cm:
            fetchContext("test_query")

        self.assertEqual(
            cm.exception.args[0], "Table test_table returned empty result"
        )

    @patch("app.sqlalchemy")
    @patch("app.Transformer")
    def test_fetchContext_with_database_error(self, mock_transformer, mock_sqlalchemy):
        mock_connection = MagicMock()
        mock_connection.execute.side_effect = sqlalchemy.exc.DatabaseError(
            "Database error"
        )
        mock_sqlalchemy.text.return_value = mock_connection

        with self.assertRaises(sqlalchemy.exc.DataError) as cm:
            fetchContext("test_query")

        self.assertEqual(
            cm.exception.args[0],
            "Database project_id:us-central1:cloudsql-instance does not exist: Database error",
        )

    @patch("app.sqlalchemy")
    @patch("app.Transformer")
    def test_fetchContext_with_table_error(self, mock_transformer, mock_sqlalchemy):
        mock_connection = MagicMock()
        mock_connection.execute.side_effect = sqlalchemy.exc.DBAPIError(
            "Table error"
        )
        mock_sqlalchemy.text.return_value = mock_connection

        with self.assertRaises(sqlalchemy.exc.DataError) as cm:
            fetchContext("test_query")

        self.assertEqual(
            cm.exception.args[0],
            "Table test_table does not exist: Table error",
        )

    @patch("app.sqlalchemy")
    @patch("app.Transformer")
    def test_fetchContext_with_general_error(self, mock_transformer, mock_sqlalchemy):
        mock_connection = MagicMock()
        mock_connection.execute.side_effect = Exception("General error")
        mock_sqlalchemy.text.return_value = mock_connection

        with self.assertRaises(Exception) as cm:
            fetchContext("test_query")

        self.assertEqual(cm.exception.args[0], "General error: General error")

    @patch("app.sqlalchemy")
    @patch("app.Transformer")
    def test_storeEmbeddings(self, mock_transformer, mock_sqlalchemy):
        mock_connection = MagicMock()
        mock_connection.execute.return_value = None
        mock_sqlalchemy.text.return_value = mock_connection

        mock_transformer.encode.return_value = [7, 8, 9]

        storeEmbeddings("test_data")

        mock_sqlalchemy.text.assert_called_once_with(
            """INSERT INTO documents (text, embedding) VALUES (%s, %s)""",
        )
        mock_connection.execute.assert_called_once_with((
            "test_data", b"\x07\x08\t"
        ))

    @patch("app.sqlalchemy")
    @patch("app.Transformer")
    def test_storeEmbeddings_with_database_error(self, mock_transformer, mock_sqlalchemy):
        mock_connection = MagicMock()
        mock_connection.execute.side_effect = sqlalchemy.exc.DatabaseError(
            "Database error"
        )
        mock_sqlalchemy.text.return_value = mock_connection

        with self.assertRaises(sqlalchemy.exc.DataError) as cm:
            storeEmbeddings("test_data")

        self.assertEqual(
            cm.exception.args[0],
            "Database project_id:us-central1:cloudsql-instance does not exist: Database error",
        )

    @patch("app.sqlalchemy")
    @patch("app.Transformer")
    def test_storeEmbeddings_with_table_error(self, mock_transformer, mock_sqlalchemy):
        mock_connection = MagicMock()
        mock_connection.execute.side_effect = sqlalchemy.exc.DBAPIError(
            "Table error"
        )
        mock_sqlalchemy.text.return_value = mock_connection

        with self.assertRaises(sqlalchemy.exc.DataError) as cm:
            storeEmbeddings("test_data")

        self.assertEqual(
            cm.exception.args[0],
            "Table test_table does not exist: Table error",
        )

    @patch("app.sqlalchemy")
    @patch("app.Transformer")
    def test_storeEmbeddings_with_general_error(self, mock_transformer, mock_sqlalchemy):
        mock_connection = MagicMock()
        mock_connection.execute.side_effect = Exception("General error")
        mock_sqlalchemy.text.return_value = mock_connection

        with self.assertRaises(Exception) as cm:
            storeEmbeddings("test_data")

        self.assertEqual(cm.exception.args[0], "General error: General error")