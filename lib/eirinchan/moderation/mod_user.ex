defmodule Eirinchan.Moderation.ModUser do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mod_users" do
    field :username, :string
    field :password_hash, :string
    field :password_salt, :string
    field :role, :string, default: "admin"
    field :last_login_at, :utc_datetime_usec
    field :password, :string, virtual: true

    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password, :role, :last_login_at])
    |> update_change(:username, &normalize_string/1)
    |> validate_required([:username, :password, :role])
    |> validate_length(:username, min: 1, max: 64)
    |> validate_length(:password, min: 1, max: 255)
    |> validate_inclusion(:role, ["admin", "mod", "janitor"])
    |> put_password_fields()
    |> validate_required([:password_hash, :password_salt])
    |> unique_constraint(:username)
  end

  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:last_login_at])
  end

  defp put_password_fields(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        salt = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
        hash = hash_password(password, salt)

        changeset
        |> put_change(:password_salt, salt)
        |> put_change(:password_hash, hash)
    end
  end

  def verify_password(%__MODULE__{} = user, password) when is_binary(password) do
    expected = hash_password(password, user.password_salt || "")
    Plug.Crypto.secure_compare(user.password_hash || "", expected)
  end

  def verify_password(_user, _password), do: false

  defp hash_password(password, salt) do
    :crypto.hash(:sha256, salt <> password)
    |> Base.encode16(case: :lower)
  end

  defp normalize_string(nil), do: nil

  defp normalize_string(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
