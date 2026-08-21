# frozen_string_literal: true

# Controla as cargas de armas de um único participante.
#
# Weapon representa o formato do ataque; WeaponInventory representa o recurso
# consumível. Jogador e computador recebem instâncias independentes com o mesmo
# loadout do mapa, impedindo que o gasto de um participante altere o outro.
#
# O ataque básico é representado por nil porque possui uso ilimitado. Armas
# especiais usam inteiros não negativos. Game consulta #available? antes da
# ação e chama #consume! somente depois que AttackHandler valida o ataque.
#
# @author Júlio Pedro
# @version 1.2
class WeaponInventory
  # Erro específico para tentativa de consumir uma arma sem carga.
  class WeaponUnavailableError < StandardError; end

  # Identificadores aceitos pela camada de domínio.
  WEAPONS = %i[basic_shot missile airplane].freeze

  # Valor interno que representa uma quantidade ilimitada.
  UNLIMITED = nil

  # Cargas simétricas entregues separadamente a jogador e computador.
  LOADOUTS = {
    poca: { missile: 1, airplane: 1 }.freeze,
    lago: { missile: 2, airplane: 1 }.freeze,
    oceano: { missile: 3, airplane: 1 }.freeze
  }.freeze

  attr_reader :map_type

  # Constrói o inventário padrão de um mapa.
  #
  # @param map_type [Symbol, String] :poca, :lago ou :oceano
  # @return [WeaponInventory]
  # @raise [ArgumentError] se o mapa não possuir loadout
  def self.for_map(map_type)
    normalized_map_type = map_type.to_s.strip.to_sym
    limits = LOADOUTS[normalized_map_type]
    raise ArgumentError, "Mapa inválido para o inventário: #{map_type.inspect}" unless limits

    new(limits, map_type: normalized_map_type)
  end

  # Cria um inventário padrão ou customizado.
  #
  # O map_type pode ser nil em testes/configurações customizadas. Nesse caso,
  # Game aceita o inventário desde que ele seja independente do outro jogador.
  #
  # @param charges [#each_pair] cargas de armas especiais por identificador
  # @param map_type [Symbol, nil] mapa ao qual o inventário pertence
  # @raise [ArgumentError] para arma desconhecida ou carga inválida
  def initialize(charges = {}, map_type: nil)
    normalized_charges = normalize_charges(charges)
    @map_type = map_type
    @remaining = WEAPONS.to_h do |weapon|
      [weapon, weapon == :basic_shot ? UNLIMITED : normalized_charges.fetch(weapon, 0)]
    end
  end

  # Consulta disponibilidade sem modificar o inventário.
  #
  # @param weapon [Weapon, Symbol, String] arma ou identificador
  # @return [Boolean]
  def available?(weapon)
    uses = remaining(weapon)
    uses.nil? || uses.positive?
  end

  # @param weapon [Weapon, Symbol, String] arma ou identificador
  # @return [Integer, nil] carga restante; nil significa ilimitada
  # @raise [KeyError, ArgumentError] se a arma não for reconhecida
  def remaining(weapon)
    @remaining.fetch(identifier_for(weapon))
  end

  # Consome uma carga e retorna a quantidade restante.
  #
  # O tiro básico não modifica estado e retorna nil. A disponibilidade é
  # verificada novamente aqui para proteger o objeto mesmo quando usado fora de
  # Game.
  #
  # @param weapon [Weapon, Symbol, String] arma ou identificador
  # @return [Integer, nil] quantidade restante após o consumo
  # @raise [WeaponUnavailableError] se a carga especial chegou a zero
  def consume!(weapon)
    identifier = identifier_for(weapon)
    return UNLIMITED if @remaining[identifier].nil?

    unless @remaining[identifier].positive?
      raise WeaponUnavailableError, "A arma #{identifier} não possui cargas restantes"
    end

    @remaining[identifier] -= 1
  end

  # Expõe uma cópia congelada para leitura por interface e testes.
  #
  # @return [Hash] identificadores associados a Integer ou nil
  def to_h
    @remaining.dup.freeze
  end

  private

  # Normaliza e valida somente as cargas configuráveis.
  # O ataque básico não pode ser redefinido como limitado.
  #
  # @api private
  def normalize_charges(charges)
    unless charges.respond_to?(:each_pair)
      raise ArgumentError, "charges precisa ser um Hash"
    end

    charges.each_pair.to_h do |weapon, amount|
      identifier = identifier_for(weapon)
      if identifier == :basic_shot
        raise ArgumentError, "O ataque básico é sempre ilimitado"
      end
      unless amount.is_a?(Integer) && amount >= 0
        raise ArgumentError, "A quantidade de #{identifier} deve ser um inteiro não negativo"
      end

      [identifier, amount]
    end
  end

  # Aceita tanto objetos Weapon quanto seus identificadores públicos.
  #
  # @return [Symbol]
  # @api private
  def identifier_for(weapon)
    raw_identifier = weapon.respond_to?(:identifier) ? weapon.identifier : weapon
    identifier = raw_identifier.to_s.strip.to_sym
    return identifier if WEAPONS.include?(identifier)

    raise ArgumentError, "Arma inválida: #{raw_identifier.inspect}"
  end
end
